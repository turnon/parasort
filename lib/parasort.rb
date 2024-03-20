# frozen_string_literal: true

require_relative "parasort/version"

require "fileutils"
require "xenum"

module Parasort
  class S
    attr_reader :tempdir

    def initialize(lines)
      @lines = lines
      @tempdir = File.join('/tmp', Time.now.strftime('%Y%m%d_%H%M%S'))
      @files = Files.new(@tempdir)
      work
    end

    def work
      FileUtils.mkdir(tempdir)

      @lines.each_slice(10000).each_with_index do |ls, i|
        ls.sort!
        dest = File.join(tempdir, "#{i}_#{i}")
        File.open(dest, 'w'){ |f| f.puts ls }
        @files.add(0, dest)
      end

      nil
    end
  end

  class Files
    attr_reader :tempdir

    def initialize(tempdir)
      @tempdir = tempdir
      @files = Hash.new{ |h, k| h[k] = [] }
    end

    def add(level, path)
      @files[level] << path
      loop do
        lvl, fs = @files.detect{ |level, fs| fs.size >= 128 }
        break unless lvl

        @files[lvl + 1] << merge(fs)
        @files[lvl].clear
      end
      path
    end

    def merge(files)
      min, max = files.map{ |f| File.basename(f).split('_').map(&:to_i) }.flatten.minmax

      # move to one dir
      merging_dir = File.join(tempdir, "merging_#{min}_#{max}")
      FileUtils.mkdir(merging_dir)
      FileUtils.mv(files, merging_dir)
      files = files.map{ |f| File.join(merging_dir, File.basename(f)) }

      merged_file = File.join(tempdir, "#{min}_#{max}")
      File.open(merged_file, 'w') do |dest|
        lineses = files.map{ |src| File.foreach(src) }
        [].merge_sort(*lineses).each_slice(10000) do |lines|
          dest.puts lines
        end
      end

      FileUtils.rm_rf(merging_dir)
      merged_file
    end
  end
end
