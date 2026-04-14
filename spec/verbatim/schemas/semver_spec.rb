# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verbatim::Schemas::SemVer do
  describe ".parse" do
    it "parses core only" do
      v = described_class.parse("0.0.0")
      expect(v.major).to eq(0)
      expect(v.minor).to eq(0)
      expect(v.patch).to eq(0)
      expect(v.prerelease).to be_nil
      expect(v.build).to be_nil
    end

    it "parses prerelease" do
      v = described_class.parse("1.2.3-alpha")
      expect(v.to_s).to eq("1.2.3-alpha")
      expect(v.prerelease).to eq("alpha")
    end

    it "parses dot-separated prerelease identifiers" do
      v = described_class.parse("1.0.0-x.7.z.92")
      expect(v.prerelease).to eq("x.7.z.92")
      expect(v.to_s).to eq("1.0.0-x.7.z.92")
    end

    it "parses build metadata" do
      v = described_class.parse("1.0.0+build.1")
      expect(v.build).to eq("build.1")
      expect(v.to_s).to eq("1.0.0+build.1")
    end

    it "parses prerelease and build" do
      v = described_class.parse("1.0.0-rc.1+exp.sha.5114f85")
      expect(v.prerelease).to eq("rc.1")
      expect(v.build).to eq("exp.sha.5114f85")
      expect(v.to_s).to eq("1.0.0-rc.1+exp.sha.5114f85")
    end

    it "parses build without prerelease" do
      v = described_class.parse("1.0.0+meta")
      expect(v.prerelease).to be_nil
      expect(v.build).to eq("meta")
      expect(v.to_s).to eq("1.0.0+meta")
    end

    it "rejects leading zeros in numeric core identifiers" do
      expect { described_class.parse("1.01.1") }.to raise_error(Verbatim::ParseError)
    end

    it "rejects empty prerelease" do
      expect { described_class.parse("1.0.0-") }.to raise_error(Verbatim::ParseError)
    end

    it "rejects invalid prerelease identifier" do
      expect { described_class.parse("1.0.0-01") }.to raise_error(Verbatim::ParseError, /invalid semver identifier/)
    end

    it "rejects empty build" do
      expect { described_class.parse("1.0.0+") }.to raise_error(Verbatim::ParseError)
    end

    it "includes segment on parse errors when applicable" do
      expect { described_class.parse("1.0.0-01") }.to raise_error(Verbatim::ParseError) do |e|
        expect(e.segment).to eq(:prerelease)
      end
    end
  end

  describe "round-trip" do
    examples = [
      "1.0.0",
      "0.1.0",
      "10.20.30",
      "1.0.0-alpha",
      "1.0.0-alpha.1",
      "1.0.0-0.3.7",
      "1.0.0-x.7.z.92",
      "1.0.0+build.1",
      "1.0.0-alpha+build.1"
    ]

    it "round-trips representative strings" do
      examples.each do |s|
        expect(described_class.parse(s).to_s).to eq(s)
      end
    end
  end

  describe "ParseError" do
    it "exposes string and index" do
      expect { described_class.parse("1.2") }.to raise_error(Verbatim::ParseError) do |e|
        expect(e.string).to eq("1.2")
        expect(e.index).to be_a(Integer)
      end
    end
  end

  describe "Comparable (SemVer 2.0.0 precedence)" do
    it "orders prerelease before release for the same core" do
      rel = described_class.parse("1.0.0")
      pre = described_class.parse("1.0.0-alpha")
      expect(pre < rel).to be true
    end

    it "orders the spec example chain" do
      ordered = %w[
        1.0.0-alpha
        1.0.0-alpha.1
        1.0.0-alpha.beta
        1.0.0-beta
        1.0.0-beta.2
        1.0.0-beta.11
        1.0.0-rc.1
        1.0.0
      ]
      shuffled = ordered.shuffle.map { described_class.parse(_1) }.sort.map(&:to_s)
      expect(shuffled).to eq(ordered)
    end

    it "orders numeric prerelease identifiers numerically" do
      expect(described_class.parse("1.0.0-1") < described_class.parse("1.0.0-2")).to be true
    end

    it "uses build only as a tie-breaker after core and prerelease" do
      a = described_class.parse("1.0.0+a")
      b = described_class.parse("1.0.0+b")
      expect(a < b).to be true
      expect(described_class.parse("1.0.0-alpha+a") < described_class.parse("1.0.0-alpha+b")).to be true
    end

    it "is consistent with #==" do
      x = described_class.parse("2.0.0")
      y = described_class.parse("2.0.0")
      expect((x <=> y).zero?).to be true
    end
  end

  describe "#succ" do
    it "increments patch and clears prerelease and build" do
      v = described_class.parse("1.0.0-rc.1+meta")
      expect(v.succ.to_s).to eq("1.0.1")
    end

    it "increments patch on a plain release" do
      expect(described_class.parse("2.3.4").succ.to_s).to eq("2.3.5")
    end
  end

  describe "#pred" do
    it "decrements patch when positive" do
      expect(described_class.parse("1.0.5").pred.to_s).to eq("1.0.4")
    end

    it "borrows from minor when patch is zero" do
      expect(described_class.parse("1.1.0").pred.to_s).to eq("1.0.0")
    end

    it "borrows from major when minor and patch are zero" do
      expect(described_class.parse("2.0.0").pred.to_s).to eq("1.0.0")
    end

    it "raises for 0.0.0" do
      expect { described_class.parse("0.0.0").pred }.to raise_error(ArgumentError, /no predecessor/)
    end

    it "raises when prerelease is present" do
      expect { described_class.parse("1.0.0-alpha").pred }.to raise_error(ArgumentError, /plain major/)
    end

    it "raises when build is present" do
      expect { described_class.parse("1.0.0+meta").pred }.to raise_error(ArgumentError, /plain major/)
    end
  end
end
