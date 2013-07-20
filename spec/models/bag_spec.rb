describe "Bag" do
  Bag = MotionPrime::Bag

  before do
    MotionPrime::Store.connect
  end

  after do
    MotionPrime::Store.shared_store.clear
  end

  describe "#<<" do
    it "should add objects to bag" do
      bag = Bag.bag

      # use << method to add object to bag
      bag << Page.new(:text => "Hello", :index => 1)

      bag.unsaved.count.should.be == 1
      bag.changed?.should.be.true
      bag.save

      bag.unsaved.count.should.be == 0
      bag.saved.count.should.be == 1
      bag.changed?.should.be.false
    end
  end

  describe "#+" do
    it "should add objects to bag" do
      bag = Bag.bag

      # use + method to add object to bag
      bag += Page.new(:text => "World", :index => 2)

      bag.unsaved.count.should.be == 1
      bag.changed?.should.be.true
      bag.save

      bag.unsaved.count.should.be == 0
      bag.saved.count.should.be == 1
      bag.changed?.should.be.false
    end
  end

  describe "#delete" do
    it "should delete object from bag" do
      bag = Bag.bag

      page = Page.new(:text => "Hello", :index => 1)
      bag << page
      bag << Page.new(:text => "World", :index => 2)
      bag.save
      bag.saved.count.should.be == 2

      bag.delete(page)
      bag.changed?.should.be.true
      bag.removed.count.should.be == 1
      bag.save
      bag.saved.count.should.be == 1
    end
  end

  describe "#store=" do
    it "should store bag" do
      store = MotionPrime::Store.create
      bag = Bag.bag
      bag.store = store
      bag << Page.new(:text => "1")
      bag.save
      store.bags.size.should == 1
      store.bags.first.to_a.first.text.should == "1"
    end
  end

  describe "#to_a" do
    it "convert a bag to array" do
      bag = Bag.bag
      bag << Page.new(:text => "1", :index => 1)
      bag << Page.new(:text => "2", :index => 2)

      bag.to_a.is_a?(Array).should.be.true
      bag.to_a.size.should == 2

      # #to_a is not ordered!
      ["1", "2"].include?(bag.to_a[0].text).should.be.true
      ["1", "2"].include?(bag.to_a[1].text).should.be.true
      bag.save
      bag.to_a.size.should == 2
    end
  end
end