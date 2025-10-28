require 'find'
require 'fileutils'
require 'tmpdir'

RSpec.describe Dotsync::DirectoryDiffer do
  let(:src) { Dir.mktmpdir }
  let(:dest) { Dir.mktmpdir }
  let(:mapping) { double(src: src, dest: dest, force?: false, ignores: []) }
  subject(:differ) { described_class.new(mapping) }

  after do
    FileUtils.remove_entry src
    FileUtils.remove_entry dest
  end

  describe '#diff' do
    context 'when file sizes are different' do
      it 'includes the file in the differences' do
        File.write(File.join(src, 'file1.txt'), 'content1')
        File.write(File.join(dest, 'file1.txt'), 'content2-different')

        expect(differ.diff).to include('file1.txt')
      end
    end

    context 'when file sizes are the same but mtimes differ' do
      it 'does not include the file in the differences' do
        File.write(File.join(src, 'file2.txt'), 'content')
        File.write(File.join(dest, 'file2.txt'), 'content')

        File.utime(Time.now - 3600, Time.now - 3600, File.join(src, 'file2.txt'))

        expect(differ.diff).to be_empty
      end
    end
  end
end

