require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')
require 'cc_deville'

class YoutubeTest < ActiveSupport::TestCase
  test "should parse YouTube user" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'Porta dos Fundos', data['author_name']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal data[:raw][:api][:video_count].to_s, data['video_count']
    assert_equal data[:raw][:api][:subscriber_count].to_s, data['subscriber_count']
  end

  test "should parse YouTube channel" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username'].downcase
    assert_equal 'Iron Maiden', data['author_name']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
    assert_equal data[:raw][:api][:video_count].to_s, data['video_count']
    assert_equal data[:raw][:api][:subscriber_count].to_s, data['subscriber_count']
  end

  test "should not cache result" do
    Media.any_instance.stubs(:parse).once
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.unstub(:parse)
  end

  test "should cache result" do
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.stubs(:parse).never
    create_media url: 'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ'
    Media.any_instance.unstub(:parse)
  end

  test "should parse YouTube user with slash" do
    m = create_media url: 'https://www.youtube.com/user/portadosfundos/'
    data = m.as_json
    assert_equal 'Porta dos Fundos', data['title']
    assert_equal 'portadosfundos', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should parse YouTube channel with slash" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ/'
    data = m.as_json
    assert_equal 'Iron Maiden', data['title']
    assert_equal 'ironmaiden', data['username']
    assert_equal 'channel', data['subtype']
    assert_not_nil data['description']
    assert_not_nil data['picture']
    assert_not_nil data['published_at']
  end

  test "should return YouTube fields" do
    url = 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    id = Media.get_id url
    m = create_media url: url
    data = m.as_json
    assert_match /^http/, data['author_picture']
    assert_equal data[:raw][:api]['channel_title'], data['username']
    assert_equal data[:raw][:api]['description'], data['description']
    assert_equal data[:raw][:api]['title'], data['title']
    assert_match /#{id}\/picture/, data['picture']
    assert_equal m.html_for_youtube_item('mtLxD7r4BZQ'), data['html']
    assert_equal data[:raw][:api]['channel_title'], data['author_name']
    assert_equal 'https://www.youtube.com/channel/' + data[:raw][:api]['channel_id'], data['author_url']
    assert_equal data[:raw][:api]['published_at'], data['published_at']
  end

  test "should store data of item returned by Youtube API" do
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert !data['title'].blank?
    assert_not_nil data['published_at']
  end

  test "should store data of profile returned by Youtube API" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert data['raw']['api'].is_a? Hash
    assert !data['raw']['api'].empty?

    assert !data['title'].blank?
    assert !data['description'].blank?
    assert !data['published_at'].blank?
    assert !data['picture'].blank?
  end

  test "should store oembed data of a youtube item" do
    Media.any_instance.stubs(:get_html).returns(Nokogiri::HTML("<link rel='alternate' type='application/json+oembed' href='http://www.youtube.com/oembed?format=json&amp;url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DmtLxD7r4BZQ' title='RubyConf Portugal 2016 - Best Of'>"))
    m = create_media url: 'https://www.youtube.com/watch?v=mtLxD7r4BZQ'
    data = m.as_json

    assert data['raw']['oembed'].is_a? Hash
    assert_equal "https:\/\/www.youtube.com\/", data['raw']['oembed']['provider_url']
    assert_equal "YouTube", data['raw']['oembed']['provider_name']

    Media.any_instance.unstub(:get_html)
  end

  test "should store oembed data of a youtube profile" do
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json

    assert_nil data['raw']['oembed']
    assert_equal 'ironmaiden', data['oembed']['author_name']
    assert_equal 'Iron Maiden', data['oembed']['title']
  end

  test "should get all thumbnails available and set the highest resolution as picture for item" do
    urls = {
      'https://www.youtube.com/watch?v=yyougTzksw8' => { available: ['default', 'high', 'medium'], best: 'high' },
      'https://www.youtube.com/watch?v=8Rd5diO16yM' => { available: ['default', 'high', 'medium', 'standard'], best: 'standard' },
      'https://www.youtube.com/watch?v=WxnN05vOuSM' => { available: ['default', 'high', 'medium', 'standard', 'maxres'], best: 'maxres' }
    }
    urls.each_pair do |url, thumbnails|
      id = Media.get_id url
      m = create_media url: url
      data = m.as_json
      assert_equal thumbnails[:available].sort, data[:raw][:api]['thumbnails'].keys.sort

      assert_match /#{id}\/picture.jpg/, data[:picture]
      saved_img = Pender::Store.current.read(data['picture'].match(/medias\/#{id}\/picture.jpg/)[0])

      open(Media.parse_url(data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'])) do |content|
        Pender::Store.current.store_object("#{id}/parsed-image.jpg", content, 'medias/')
      end
      parsed_img = Pender::Store.current.read("medias/#{id}/parsed-image.jpg")

      assert_equal parsed_img, saved_img
    end
  end

  test "should get all thumbnails available and set the highest resolution as picture for profile" do
    urls = {
      'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ' => { available: ['default', 'high', 'medium'], best: 'high' },
      'https://www.youtube.com/channel/UCZbgt7KIEF_755Xm14JpkCQ' => { available: ['default', 'high', 'medium'], best: 'high' }
    }
    urls.each_pair do |url, thumbnails|
      id = Media.get_id url
      m = create_media url: url
      data = m.as_json
      assert_equal thumbnails[:available].sort, data[:raw][:api]['thumbnails'].keys.sort

      assert_match /#{id}\/picture.jpg/, data[:picture]
      saved_img = Pender::Store.current.read(data['picture'].match(/medias\/#{id}\/picture.jpg/)[0])

      open(Media.parse_url(data[:raw][:api]['thumbnails'][thumbnails[:best]]['url'])) do |content|
        Pender::Store.current.store_object("#{id}/parsed-image.jpg", content, 'medias/')
      end
      parsed_img = Pender::Store.current.read("medias/#{id}/parsed-image.jpg")

      assert_equal parsed_img, saved_img
    end
  end

  test "should not crash when parsing a deleted YouTube video" do
    url = 'https://www.youtube.com/watch?v=6q_Tcyeq5fk&feature=youtu.be'
    m = create_media url: url
    data = m.as_json
    assert_equal 'YouTube', data['username']
    assert_equal 'Deleted video', data['title']
    assert_equal 'This video is unavailable.', data['description']
    assert_equal '', data['author_url']
    assert_equal '', data[:raw][:api]['thumbnails']
    assert_equal '', data['picture']
    assert_equal '', data['html']
  end

  test "should have external id for video" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.youtube.com/watch?v=qMfu1GLVsiM'>"))
    m = create_media url: 'https://www.youtube.com/watch?v=qMfu1GLVsiM'
    data = m.as_json
    assert_equal 'qMfu1GLVsiM', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should have external id for profile" do
    Media.any_instance.stubs(:doc).returns(Nokogiri::HTML("<meta property='og:url' content='https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'>"))
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ'
    data = m.as_json
    assert_equal 'UCaisXKBdNOYqGr2qOXCLchQ', data['external_id']
    Media.any_instance.unstub(:doc)
  end

  test "should not parse a youtube post when passing the google_api_key is empty" do
    key = create_api_key application_settings: { config: { google_api_key: '' } }
    m = create_media url: 'https://www.youtube.com/channel/UCaisXKBdNOYqGr2qOXCLchQ', key: key
    assert_equal '', PenderConfig.get(:google_api_key)
    data = m.as_json
    assert_equal "", data['title']
    assert_match "The request is missing a valid API key.", data['error']['message']
  end
end
