# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "benchmark"

RSpec.describe Dotsync::ConfigCache do
  let(:config_content) do
    <<~TOML
      [[pull.mappings]]
      src = "$HOME/dotfiles"
      dest = "$HOME/.config"
    TOML
  end

  let(:temp_config_file) do
    file = Tempfile.new(["dotsync", ".toml"])
    file.write(config_content)
    file.flush
    file
  end

  let(:temp_config_path) { temp_config_file.path }

  after do
    # Close and unlink temp file
    if defined?(temp_config_file) && temp_config_file
      temp_config_file.close
      temp_config_file.unlink
    end

    # Clean up cache directory - try with a valid path first
    if defined?(temp_config_path) && temp_config_path && File.exist?(temp_config_path)
      cache = described_class.new(temp_config_path)
      cache_dir = cache.instance_variable_get(:@cache_dir)
      FileUtils.rm_rf(cache_dir) if cache_dir && File.exist?(cache_dir)
    end
  end

  describe "#initialize" do
    it "expands the config path" do
      cache = described_class.new(temp_config_path)
      config_path = cache.instance_variable_get(:@config_path)
      expect(config_path).to eq(File.expand_path(temp_config_path))
    end

    it "creates cache directory path in XDG_DATA_HOME" do
      cache = described_class.new(temp_config_path)
      cache_dir = cache.instance_variable_get(:@cache_dir)
      expect(cache_dir).to include("dotsync/config_cache")
    end

    it "generates unique cache filenames based on path hash" do
      cache1 = described_class.new(temp_config_path)
      cache_file1 = cache1.instance_variable_get(:@cache_file)

      file2 = Tempfile.new(["dotsync2", ".toml"])
      file2.write(config_content)
      file2.flush
      path2 = file2.path
      file2.close

      cache2 = described_class.new(path2)
      cache_file2 = cache2.instance_variable_get(:@cache_file)

      expect(cache_file1).not_to eq(cache_file2)

      File.delete(path2) if File.exist?(path2)
    end
  end

  describe "#load" do
    context "when cache is disabled via environment variable" do
      it "resolves config directly without using cache" do
        ENV["DOTSYNC_NO_CACHE"] = "1"
        cache = described_class.new(temp_config_path)

        expect(cache).to receive(:resolve_config).and_call_original
        expect(cache).not_to receive(:valid_cache?)

        result = cache.load
        expect(result).to be_a(Hash)
        expect(result).to have_key("pull")

        ENV.delete("DOTSYNC_NO_CACHE")
      end
    end

    context "when cache does not exist" do
      it "parses TOML and creates cache files" do
        cache = described_class.new(temp_config_path)

        result = cache.load

        expect(result).to be_a(Hash)
        expect(result).to have_key("pull")

        cache_file = cache.instance_variable_get(:@cache_file)
        meta_file = cache.instance_variable_get(:@meta_file)

        expect(File.exist?(cache_file)).to be true
        expect(File.exist?(meta_file)).to be true
      end

      it "stores metadata with source information" do
        cache = described_class.new(temp_config_path)
        cache.load

        meta_file = cache.instance_variable_get(:@meta_file)
        metadata = JSON.parse(File.read(meta_file))

        expect(metadata).to have_key("source_path")
        expect(metadata).to have_key("source_size")
        expect(metadata).to have_key("source_mtime")
        expect(metadata).to have_key("cached_at")
        expect(metadata).to have_key("dotsync_version")
        expect(metadata["dotsync_version"]).to eq(Dotsync::VERSION)
      end
    end

    context "when cache exists and is valid" do
      it "loads from cache without resolving config" do
        cache = described_class.new(temp_config_path)

        # First load creates cache
        cache.load

        # Second load should use cache
        expect(cache).not_to receive(:resolve_config)
        result = cache.load

        expect(result).to be_a(Hash)
        expect(result).to have_key("pull")
      end

      it "is faster than parsing TOML" do
        cache = described_class.new(temp_config_path)

        # First load creates cache
        cache.load

        # Measure cache load time (multiple runs for accuracy)
        cache_times = []
        5.times { cache_times << Benchmark.realtime { cache.load } }
        cache_load_time = cache_times.min

        # Measure TOML parse time (multiple runs for accuracy)
        parse_times = []
        5.times { parse_times << Benchmark.realtime { TomlRB.load_file(temp_config_path) } }
        parse_time = parse_times.min

        # Cache should be faster (at least 2x)
        expect(cache_load_time).to be < (parse_time / 2)
      end
    end

    context "when cache is invalid" do
      it "recreates cache when cache file is missing" do
        cache = described_class.new(temp_config_path)
        cache.load

        cache_file = cache.instance_variable_get(:@cache_file)
        File.delete(cache_file)

        expect(cache).to receive(:parse_and_cache).and_call_original
        result = cache.load

        expect(File.exist?(cache_file)).to be true
        expect(result).to have_key("pull")
      end

      it "recreates cache when meta file is missing" do
        cache = described_class.new(temp_config_path)
        cache.load

        meta_file = cache.instance_variable_get(:@meta_file)
        File.delete(meta_file)

        expect(cache).to receive(:parse_and_cache).and_call_original
        result = cache.load

        expect(File.exist?(meta_file)).to be true
        expect(result).to have_key("pull")
      end

      it "recreates cache when source file mtime changes" do
        cache = described_class.new(temp_config_path)
        cache.load

        # Modify the source file
        sleep 0.1 # Ensure mtime changes
        File.write(temp_config_path, config_content + "\n# comment")

        expect(cache).to receive(:parse_and_cache).and_call_original
        cache.load
      end

      it "recreates cache when source file size changes" do
        cache = described_class.new(temp_config_path)
        cache.load

        # Change file size
        File.write(temp_config_path, config_content + "\n\n\n")

        expect(cache).to receive(:parse_and_cache).and_call_original
        cache.load
      end

      it "recreates cache when dotsync version changes" do
        cache = described_class.new(temp_config_path)
        cache.load

        meta_file = cache.instance_variable_get(:@meta_file)
        metadata = JSON.parse(File.read(meta_file))
        metadata["dotsync_version"] = "0.0.1"
        File.write(meta_file, JSON.generate(metadata))

        expect(cache).to receive(:parse_and_cache).and_call_original
        cache.load
      end

      it "recreates cache when cache is older than 7 days" do
        cache = described_class.new(temp_config_path)
        cache.load

        meta_file = cache.instance_variable_get(:@meta_file)
        metadata = JSON.parse(File.read(meta_file))
        metadata["cached_at"] = (Time.now - (8 * 86400)).to_f # 8 days ago
        File.write(meta_file, JSON.generate(metadata))

        expect(cache).to receive(:parse_and_cache).and_call_original
        cache.load
      end
    end

    context "when cache is corrupted" do
      it "falls back to parsing TOML when Marshal.load fails" do
        cache = described_class.new(temp_config_path)
        cache.load

        # Corrupt the cache file
        cache_file = cache.instance_variable_get(:@cache_file)
        File.write(cache_file, "corrupted data")

        expect(cache).to receive(:parse_and_cache).and_call_original
        result = cache.load

        expect(result).to have_key("pull")
      end

      it "handles JSON parsing errors in metadata" do
        cache = described_class.new(temp_config_path)
        cache.load

        # Corrupt the meta file
        meta_file = cache.instance_variable_get(:@meta_file)
        File.write(meta_file, "{ invalid json")

        expect(cache).to receive(:parse_and_cache).and_call_original
        result = cache.load

        expect(result).to have_key("pull")
      end
    end

    context "when cache write fails" do
      it "returns parsed config even if caching fails" do
        cache = described_class.new(temp_config_path)

        # Make cache directory read-only
        cache_dir = cache.instance_variable_get(:@cache_dir)
        FileUtils.mkdir_p(cache_dir)
        FileUtils.chmod(0o444, cache_dir)

        result = cache.load rescue nil

        # Restore permissions for cleanup
        FileUtils.chmod(0o755, cache_dir)

        expect(result).to be_a(Hash)
        expect(result).to have_key("pull")
      end
    end
  end

  describe "#valid_cache?" do
    it "returns false when cache file does not exist" do
      cache = described_class.new(temp_config_path)
      expect(cache.send(:valid_cache?)).to be false
    end

    it "returns false when meta file does not exist" do
      cache = described_class.new(temp_config_path)

      cache_file = cache.instance_variable_get(:@cache_file)
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, "data")

      expect(cache.send(:valid_cache?)).to be false
    end

    it "returns true for valid cache" do
      cache = described_class.new(temp_config_path)
      cache.load

      expect(cache.send(:valid_cache?)).to be true
    end

    it "returns false when validation raises an error" do
      cache = described_class.new(temp_config_path)
      cache.load

      # Cause an error in File.stat
      allow(File).to receive(:stat).and_raise(StandardError.new("test error"))

      expect(cache.send(:valid_cache?)).to be false
    end
  end

  describe "#parse_and_cache" do
    it "creates cache directory if it doesn't exist" do
      cache = described_class.new(temp_config_path)
      cache_dir = cache.instance_variable_get(:@cache_dir)

      FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)

      cache.send(:parse_and_cache)

      expect(File.directory?(cache_dir)).to be true
    end

    it "writes Marshal dump of config" do
      cache = described_class.new(temp_config_path)
      result = cache.send(:parse_and_cache)

      cache_file = cache.instance_variable_get(:@cache_file)
      cached_data = Marshal.load(File.binread(cache_file))

      expect(cached_data).to eq(result)
    end

    it "returns parsed config even when caching fails" do
      cache = described_class.new(temp_config_path)

      # Prevent cache file writing
      allow(File).to receive(:binwrite).and_raise(StandardError.new("write error"))

      result = cache.send(:parse_and_cache)

      expect(result).to be_a(Hash)
      expect(result).to have_key("pull")
    end
  end

  describe "#parse_toml" do
    it "requires toml-rb and loads the config file" do
      cache = described_class.new(temp_config_path)
      result = cache.send(:parse_toml)

      expect(result).to be_a(Hash)
      expect(result).to have_key("pull")
      expect(result["pull"]).to have_key("mappings")
    end
  end

  describe "#build_metadata" do
    it "includes all required metadata fields" do
      cache = described_class.new(temp_config_path)
      cache.send(:resolve_config)
      metadata = cache.send(:build_metadata)

      expect(metadata).to have_key(:source_path)
      expect(metadata).to have_key(:source_size)
      expect(metadata).to have_key(:source_mtime)
      expect(metadata).to have_key(:cached_at)
      expect(metadata).to have_key(:dotsync_version)
    end

    it "captures current source file statistics" do
      cache = described_class.new(temp_config_path)
      cache.send(:resolve_config)
      metadata = cache.send(:build_metadata)

      stat = File.stat(temp_config_path)

      expect(metadata[:source_size]).to eq(stat.size)
      expect(metadata[:source_mtime]).to eq(stat.mtime.to_f)
    end

    it "includes current dotsync version" do
      cache = described_class.new(temp_config_path)
      cache.send(:resolve_config)
      metadata = cache.send(:build_metadata)

      expect(metadata[:dotsync_version]).to eq(Dotsync::VERSION)
    end
  end

  describe "include-aware caching" do
    let(:include_dir) { File.join("/tmp", "dotsync_include_cache_spec") }
    let(:base_path) { File.join(include_dir, "base.toml") }
    let(:overlay_path) { File.join(include_dir, "overlay.toml") }

    before do
      FileUtils.mkdir_p(include_dir)
      File.write(base_path, <<~TOML)
        [[pull.mappings]]
        src = "$HOME/dotfiles"
        dest = "$HOME/.config"
      TOML
      File.write(overlay_path, <<~TOML)
        include = "base.toml"

        [[pull.mappings]]
        src = "$HOME/extra"
        dest = "$HOME/.extra"
      TOML
    end

    after do
      FileUtils.rm_rf(include_dir)
    end

    it "invalidates cache when include file mtime changes" do
      cache = described_class.new(overlay_path)
      cache.load

      sleep 0.1
      FileUtils.touch(base_path)

      expect(cache).to receive(:parse_and_cache).and_call_original
      cache.load
    end

    it "invalidates cache when include file size changes" do
      cache = described_class.new(overlay_path)
      cache.load

      File.write(base_path, <<~TOML)
        [[pull.mappings]]
        src = "$HOME/dotfiles"
        dest = "$HOME/.config"

        [[pull.mappings]]
        src = "$HOME/more"
        dest = "$HOME/.more"
      TOML

      expect(cache).to receive(:parse_and_cache).and_call_original
      cache.load
    end

    it "invalidates cache when include file is deleted" do
      cache = described_class.new(overlay_path)
      cache.load

      File.delete(base_path)

      expect(cache.send(:valid_cache?)).to be false
    end

    it "stores include file stats in metadata" do
      cache = described_class.new(overlay_path)
      cache.load

      meta_file = cache.instance_variable_get(:@meta_file)
      metadata = JSON.parse(File.read(meta_file))

      expect(metadata).to have_key("include_path")
      expect(metadata).to have_key("include_mtime")
      expect(metadata).to have_key("include_size")
      expect(metadata["include_path"]).to eq(base_path)
    end

    it "works in no-cache mode with includes" do
      ENV["DOTSYNC_NO_CACHE"] = "1"
      cache = described_class.new(overlay_path)

      result = cache.load
      expect(result).to be_a(Hash)
      expect(result["pull"]["mappings"].length).to eq(2)

      ENV.delete("DOTSYNC_NO_CACHE")
    end

    it "does not store include metadata when no include" do
      cache = described_class.new(temp_config_path)
      cache.load

      meta_file = cache.instance_variable_get(:@meta_file)
      metadata = JSON.parse(File.read(meta_file))

      expect(metadata).not_to have_key("include_path")
      expect(metadata).not_to have_key("include_mtime")
      expect(metadata).not_to have_key("include_size")
    end
  end
end
