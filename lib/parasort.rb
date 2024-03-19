# frozen_string_literal: true

require_relative "parasort/version"

require "xenum"

module Parasort
  class S
    attr_reader :tempdir

    def initialize(lines)
      @lines = lines
      @tempdir = File.join('/tmp', Time.now.strftime('%Y%m%d_%H%M%S'))
      @files = work
    end

    def work
      FileUtils.mkdir(tempdir)
      files = Hash.new{ |h, k| h[k] = [] }

      @lines.each_slice(10000).each_with_index do |ls, i|
        ls.sort!
        dest = File.join(tempdir, "#{i}_#{i}")
        File.open(dest, 'w'){ |f| f.puts ls }
        files[0] << dest
        lvl, fs = files.detect{ |level, fs| fs.size >= 128 }
        if lvl
          files[lvl + 1] << merge(fs)
          fs.each{ |f| File.delete(f) }
          files[lvl].clear
        end
      end
      files
    end

    def merge(files)
      min = File.basename(files[0]).split('_')[0]
      max = File.basename(files[-1]).split('_')[1]
      path = File.join(tempdir, "#{min}_#{max}")
      File.open(path, 'w') do |dest|
        files.map{ |src| File.foreach(src) }.reduce(&:merge_sort).each_slice(10000) do |lines|
          dest.puts lines
        end
      end
      path
    end
  end
end
