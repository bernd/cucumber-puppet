require 'spec_helper'
require 'cucumber-puppet/puppet'

# ensure existence of different version's API
module Puppet
  class Node
    class Catalog
    end
  end
  class Resource
    class Catalog
    end
  end
end

# to access some instance variables
class TestCucumberPuppet < CucumberPuppet
  attr_accessor :catalog
  attr_reader :facts, :klass
end

describe CucumberPuppet do
  describe '#new' do
    it 'sets puppet`s logdestination to console' do
      TestCucumberPuppet.new
      Puppet::Util::Log.destinations.should include(:console)
    end
    it 'sets puppet`s loglevel to notice' do
      TestCucumberPuppet.new
      Puppet::Util::Log.level.should == :notice
    end
  end

  describe '#debug' do
    it 'sets puppet`s loglevel to debug' do
      CucumberPuppet.new.debug
      Puppet::Util::Log.level.should == :debug
    end
  end

  describe '#klass=' do
    # TODO add support for multiple classes by splitting the string
    it 'creates the array of classes from a string' do
      c = TestCucumberPuppet.new
      c.klass = "foo"
      c.klass.should == ["foo"]
    end
  end

  describe '#compile_catalog' do
    let(:c) { TestCucumberPuppet.new }

    before(:each) do
      Puppet.stub(:parse_config)
      @node = mock("node", :name => 'testnode').as_null_object
      @node.stub(:is_a?).and_return(Puppet::Node)
      Puppet::Node.stub(:new).and_return(@node)
      @catalog = mock("catalog")
      @catalog.stub(:resources).and_return([])
      Puppet::Resource::Catalog.stub(:find).and_return(@catalog)
    end

    it 'parses the puppet config' do
      Puppet.should_receive(:parse_config)
      c.compile_catalog
    end

    context 'when called without argument' do
      it 'merges facts into the node' do
        @node.should_receive(:merge).with(c.facts)
        c.compile_catalog
      end
    end

    context 'when called with a node object as argument' do
      it 'does not merge facts into the node' do
        @node.should_not_receive(:merge)
        c.compile_catalog(@node)
      end
    end

    it 'finds the node`s catalog' do
      Puppet::Resource::Catalog.should_receive(:find).with(@node.name, :use_node => @node)
      c.compile_catalog
    end

    it 'falls back to puppet`s 0.24 interface in case of NameError' do
      Puppet::Resource::Catalog.stub(:find).and_raise(NameError)
      Puppet::Node::Catalog.should_receive(:find).with(@node.name, :use_node => @node).and_return(@catalog)
      c.compile_catalog
    end

    it 'collects resource aliases' do
      r1 = mock("r1")
      r1.stub(:[]).with(:alias).and_return("foo")
      r1.stub(:type).and_return("Type")
      @catalog.stub(:resources).and_return(["r1"])
      @catalog.stub(:resource).with("r1").and_return(r1)
      c.compile_catalog
      c.instance_variable_get(:@aliases).should have_key("Type[foo]")
    end
  end

  describe '#resource' do
    # XXX duplication
    context 'given the name of a resource' do
      it 'returns an entry from the catalog' do
        c = TestCucumberPuppet.new
        c.catalog = mock("catalog").as_null_object
        c.catalog.should_receive(:resource).with("foo")
        c.resource("foo")
      end
    end

    context 'given the alias of a resource' do
      it 'returns an entry from the catalog' do
        c = TestCucumberPuppet.new
        c.catalog = mock("catalog")
        c.catalog.stub(:resource).and_return(nil)
        c.instance_variable_set(:@aliases, { "foo" => "bar" })
        c.resource("foo").should == "bar"
      end
    end
  end

  describe '#catalog_resources' do
    let(:c) do
      TestCucumberPuppet.new.tap do |c|
        c.catalog = mock("catalog").as_null_object
      end
    end

    context 'puppet version 0.25 and older' do
      it 'returns an Array of Puppet::Resource objects' do
        c.catalog.stub(:resources).and_return([ 'one', 'two'])
        c.catalog.stub(:resource).and_return(Puppet::Resource.new("Class", "x"))
        c.catalog_resources.each do |r|
          r.should be_a(Puppet::Resource)
        end
      end
    end

    context 'puppet version 2.6 and newer' do
      it 'returns an Array of Puppet::Resource objects' do
        one = Puppet::Resource.new("Class", "one")
        two = Puppet::Resource.new("Class", "two")
        c.catalog.stub(:resources).and_return([ one, two ])
        c.catalog_resources.each do |r|
          r.should be_a(Puppet::Resource)
        end
      end
    end
  end
end
