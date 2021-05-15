require 'rspec/core'
require 'pry'

describe "example spec" do
  it "gets debugged" do
    binding.pry
    expect(true).to eq(true)
  end
end
