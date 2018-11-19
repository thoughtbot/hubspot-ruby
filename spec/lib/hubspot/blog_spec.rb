require 'timecop'

describe Hubspot do
  let(:example_blog_hash) do
    VCR.use_cassette("blog_list", record: :none) do
      url = Hubspot::Connection.send(:generate_url, Hubspot::Blog::BLOG_LIST_PATH)
      resp = HTTParty.get(url, format: :json)
      resp.parsed_response["objects"].first
    end
  end
  let(:created_range_params) { { created__gt: false, created__range: (Time.now..Time.now + 2.years)  } }

  before do
    Hubspot.configure(hapikey: "demo")
    Timecop.freeze(Time.utc(2012, 'Oct', 10))
  end

  after do
    Timecop.return
  end

  describe Hubspot::Blog do

    describe ".list" do
      cassette "blog_list"
      let(:blog_list) { Hubspot::Blog.list }

      it "should have a list of blogs" do
        blog_list.count.should be(1)
      end
    end

    describe ".find_by_id" do
      cassette "blog_list"

      it "should have a list of blogs" do
        blog = Hubspot::Blog.find_by_id(351076997)
        blog["id"].should eq(351076997)
      end
    end

    describe "#initialize" do
      subject{ Hubspot::Blog.new(example_blog_hash) }
      its(["name"]) { should == "API Demonstration Blog" }
      its(["id"])   { should == 351076997 }
    end

    describe "#posts" do
      it "returns published blog posts created in the last 2 months" do
        VCR.use_cassette("blog_posts/all_blog_posts", record: :none) do
          blog_id = 123
          created_gt = timestamp_in_milliseconds(Time.now - 2.months)
          blog = Hubspot::Blog.new({ "id" => blog_id })

          result = blog.posts

          assert_requested :get, hubspot_api_url("/content/api/v2/blog-posts?content_group_id=#{blog_id}&created__gt=#{created_gt}&hapikey=demo&order_by=-created&state=PUBLISHED")
          expect(result).to be_kind_of(Array)
        end
      end

      it "includes given parameters in the request" do
        VCR.use_cassette("blog_posts/filter_blog_posts", record: :none) do
          blog_id = 123
          created_gt = timestamp_in_milliseconds(Time.now - 2.months)
          blog = Hubspot::Blog.new({ "id" => 123 })

          result = blog.posts({ state: "DRAFT" })

          assert_requested :get, hubspot_api_url("/content/api/v2/blog-posts?content_group_id=#{blog_id}&created__gt=#{created_gt}&hapikey=demo&order_by=-created&state=DRAFT")
          expect(result).to be_kind_of(Array)
        end
      end

      it "raises when given an unknown state" do
        blog = Hubspot::Blog.new({})

        expect {
          blog.posts({ state: "unknown" })
        }.to raise_error(Hubspot::InvalidParams, "State parameter was invalid")
      end
    end
  end

  describe Hubspot::BlogPost do
    cassette "blog_posts"

    describe "#created_at" do
      it "returns the created timestamp as a Time" do
        timestamp = timestamp_in_milliseconds(Time.now)
        blog_post = Hubspot::BlogPost.new({ "created" => timestamp })

        expect(blog_post.created_at).to eq(Time.at(timestamp/1000))
      end
    end

    it "can find by blog_post_id" do
      blog = Hubspot::BlogPost.find_by_blog_post_id(422192866)
      expect(blog['id']).to eq(422192866)
    end

    context 'containing a topic' do
      # 422192866 contains a topic
      let(:blog_with_topic) { Hubspot::BlogPost.find_by_blog_post_id(422192866) }

      it "should return topic objects" do
        expect(blog_with_topic.topics.first.is_a?(Hubspot::Topic)).to be(true)
      end
    end
  end

  def hubspot_api_url(path)
    URI.join(Hubspot::Config.base_url, path)
  end

  def timestamp_in_milliseconds(time)
    time.to_i * 1000
  end
end
