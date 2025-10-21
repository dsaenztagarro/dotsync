require 'spec_helper'

RSpec.describe Dotsync::MappingEntry do
  include Dotsync::PathUtils

  let(:root) { File.join("/tmp", "dotsync") }
  let(:src) { File.join(root, "src") }
  let(:dest) { File.join(root, "dest") }
  let(:ignored_file) { File.join(src, "ignored_file") }
  let(:ignored_folder) { File.join(src, "ignored_folder") }

  let(:mapping_hash) do
    {
      "src" => src,
      "dest" => dest,
      "force" => true,
      "ignore" => ["ignored_file", "ignored_folder"]
    }
  end

  subject(:mapping_entry) { described_class.new(mapping_hash) }

  before do
    FileUtils.mkdir_p(ignored_folder)
    File.write(ignored_file, "content")
    FileUtils.mkdir_p(dest)
  end

  after do
    FileUtils.rm_rf(root)
  end

  describe '#src' do
    it 'returns the sanitized expanded source path' do
      expect(mapping_entry.src).to eq(sanitize_path(src))
    end
  end

  describe '#dest' do
    it 'returns the sanitized expanded destination path' do
      expect(mapping_entry.dest).to eq(sanitize_path(dest))
    end
  end

  describe '#force?' do
    it 'returns true if force is enabled' do
      expect(mapping_entry.force?).to be true
    end
  end

  describe '#ignores' do
    it 'returns the sanitized expanded paths of ignored files/folders' do
      expect(mapping_entry.ignores).to include(
        sanitize_path(ignored_file),
        sanitize_path(ignored_folder)
      )
    end
  end

  describe '#valid?' do
    context 'when both src and dest exist' do
      it 'returns true' do
        expect(mapping_entry.valid?).to be true
      end
    end

    context 'when either src or dest does not exist' do
      before { FileUtils.rm_rf(src) }

      it 'returns false' do
        expect(mapping_entry.valid?).to be false
      end
    end
  end
end

