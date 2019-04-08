# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'
require 'bolt/target'

describe Bolt::Result do
  let(:target1) { "node1" }
  let(:target2) { "node1" }
  let(:result_val1) { { 'key' => 'val1' } }
  let(:result_val2) { { 'key' => 'val2', '_error' => { 'kind' => 'bolt/oops' } } }
  let(:result_set) do
    Bolt::ResultSet.new([
                          Bolt::Result.new(Bolt::Target.new(target1), value: result_val1),
                          Bolt::Result.new(Bolt::Target.new(target2), value: result_val2)
                        ])
  end

  it 'is enumerable' do
    expect(result_set.map { |r| r['key'] }).to eq(%w[val1 val2])
  end

  it 'is creates the correct json' do
    expected = [{ "node" => "node1",
                  "target" => "node1",
                  "type" => nil,
                  "object" => nil,
                  "status" => "success",
                  "result" => { "key" => "val1" } },
                { "node" => "node1",
                  "target" => "node1",
                  "type" => nil,
                  "object" => nil,
                  "status" => "failure",
                  "result" => { "key" => "val2", "_error" => { "kind" => "bolt/oops" } } }]
    expect(JSON.parse(result_set.to_json)).to eq(expected)
  end
end
