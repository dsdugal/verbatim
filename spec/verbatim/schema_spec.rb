# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verbatim::Schema do
  let(:dot_pair_class) do
    Class.new(described_class) do
      delimiter "."
      segment :a, :uint
      segment :b, :uint
    end
  end

  it "parses delimited uint segments" do
    v = dot_pair_class.parse("10.20")
    expect(v.a).to eq(10)
    expect(v.b).to eq(20)
    expect(v.to_s).to eq("10.20")
  end

  it "raises on missing delimiter" do
    expect { dot_pair_class.parse("1020") }.to raise_error(Verbatim::ParseError, /delimiter/)
  end

  it "raises on trailing data" do
    expect { dot_pair_class.parse("1.2junk") }.to raise_error(Verbatim::ParseError, /trailing/)
  end

  it "rejects input longer than Verbatim::Schema::MAX_INPUT_LEN" do
    long = "0." + ("9" * 127)
    expect(long.length).to eq(129)
    expect { dot_pair_class.parse(long) }.to raise_error(Verbatim::ParseError, /maximum length/)
  end

  it "accepts input of exactly MAX_INPUT_LEN characters" do
    s = "0." + ("9" * 126)
    expect(s.length).to eq(Verbatim::Schema::MAX_INPUT_LEN)
    v = dot_pair_class.parse(s)
    expect(v.a).to eq(0)
    expect(v.b).to eq(Integer("9" * 126, 10))
  end

  it "supports #[] and to_h" do
    v = dot_pair_class.parse("0.0")
    expect(v[:a]).to eq(0)
    expect(v.to_h).to eq({ a: 0, b: 0 })
  end

  it "compares by value" do
    x = dot_pair_class.parse("1.2")
    y = dot_pair_class.parse("1.2")
    z = dot_pair_class.parse("1.3")
    expect(x).to eq(y)
    expect(x).not_to eq(z)
    expect([x, y].uniq.size).to eq(1)
  end

  describe "Comparable" do
    it "orders with < and sort for same class" do
      low = dot_pair_class.parse("1.2")
      mid = dot_pair_class.parse("1.10")
      high = dot_pair_class.parse("2.0")
      expect(low < mid).to be true
      expect(mid < high).to be true
      expect([high, low, mid].sort).to eq([low, mid, high])
    end

    it "returns nil for different schema classes" do
      other = Class.new(described_class) do
        delimiter "."
        segment :a, :uint
        segment :b, :uint
      end
      x = dot_pair_class.parse("1.2")
      y = other.parse("1.2")
      expect(x <=> y).to be_nil
    end

    it "puts nil optional segment before present (generic tuple order)" do
      with_opt = Class.new(described_class) do
        delimiter "."
        segment :major, :uint
        segment :minor, :uint, delimiter_after: :none
        segment :tag, :token, optional: true, lead: "-"
      end
      bare = with_opt.parse("1.0")
      tagged = with_opt.parse("1.0-z")
      expect(bare < tagged).to be true
      expect([tagged, bare].sort).to eq([bare, tagged])
    end
  end

  it "formats from manual construction" do
    v = dot_pair_class.new(a: 3, b: 4)
    expect(v.to_s).to eq("3.4")
  end

  it "allows custom delimiter_after :none and lead for tails" do
    tail = Class.new(described_class) do
      delimiter "."
      segment :major, :uint
      segment :minor, :uint, delimiter_after: :none
      segment :tag, :token, optional: true, lead: "-"
    end

    expect(tail.parse("1.2").to_s).to eq("1.2")
    expect(tail.parse("1.2-rc").to_s).to eq("1.2-rc")
    expect { tail.parse("1.2.rc") }.to raise_error(Verbatim::ParseError)
  end

  it "rejects duplicate segment names" do
    expect do
      Class.new(described_class) do
        delimiter "."
        segment :x, :uint
        segment :x, :uint
      end
    end.to raise_error(ArgumentError, /duplicate/)
  end

  describe ":int" do
    let(:signed) do
      Class.new(described_class) do
        delimiter "_"
        segment :n, :int
      end
    end

    it "parses negative and positive" do
      expect(signed.parse("-5").n).to eq(-5)
      expect(signed.parse("42").n).to eq(42)
      expect(signed.parse("-5").to_s).to eq("-5")
    end
  end

  describe ":string" do
    let(:rx) do
      Class.new(described_class) do
        segment :code, :string, pattern: /[A-Z]{2}\d{2}/
      end
    end

    it "parses anchored pattern" do
      v = rx.parse("AB12")
      expect(v.code).to eq("AB12")
      expect(v.to_s).to eq("AB12")
    end

    it "rejects non-matching" do
      expect { rx.parse("ab12") }.to raise_error(Verbatim::ParseError)
    end
  end

  describe ":uint leading_zeros" do
    let(:strict) do
      Class.new(described_class) do
        segment :n, :uint, leading_zeros: false
      end
    end

    it "allows single zero" do
      expect(strict.parse("0").n).to eq(0)
    end

    it "rejects leading zeros" do
      expect { strict.parse("01") }.to raise_error(Verbatim::ParseError, /leading zeros/)
    end
  end

  describe ":uint pad and range" do
    let(:padded) do
      Class.new(described_class) do
        delimiter "."
        segment :a, :uint, pad: 2
        segment :b, :uint, pad: 2, minimum: 1, maximum: 3
      end
    end

    it "formats with zero padding" do
      expect(padded.parse("1.2").to_s).to eq("01.02")
    end

    it "rejects values below minimum" do
      expect { padded.parse("01.0") }.to raise_error(Verbatim::ParseError, /minimum/)
    end
  end

  describe "#with" do
    it "returns a new instance with merged segments" do
      v = dot_pair_class.parse("1.2")
      w = v.with(b: 9)
      expect(w).not_to equal(v)
      expect(w.a).to eq(1)
      expect(w.b).to eq(9)
      expect(w.to_s).to eq("1.9")
    end

    it "accepts string keys in overrides" do
      v = dot_pair_class.parse("3.4")
      expect(v.with("a" => 0).to_s).to eq("0.4")
    end
  end

  describe "#succ and #pred" do
    it "raise NotImplementedError on a generic schema" do
      v = dot_pair_class.parse("1.2")
      expect { v.succ }.to raise_error(NotImplementedError, /#succ/)
      expect { v.pred }.to raise_error(NotImplementedError, /#pred/)
    end
  end
end
