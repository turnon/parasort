module Parasort
  class MergeSortFiles
    class Destination
      def initialize
        @buf = []
        @file = Tempfile.new('parasort_merging')
      end

      def write(line)
        @buf << line
        flush if @buf.size >= 1000
      end

      def flush
        @buf.each{ |line| @file.write(line) }
        @buf.clear
      end

      def close
        flush
        @file.flush
        @file.close
      end

      def path
        @file.path
      end
    end

    attr_reader :target

    def initialize(file_a, file_b, target: nil)
      @loop_a = File.foreach(file_a)
      @loop_b = File.foreach(file_b)
      @dest = Destination.new

      merge!
      move!(target)
    end

    private

    def move!(target)
      if target
        File.rename(@dest.path, target)
        return @target = target
      end

      @target = @dest.path
    end

    def merge!
      line_a = nil
      line_b = nil
      remain = nil

      loop do
        line_a ||= begin
                     @loop_a.next
                   rescue StopIteration
                     remain = @loop_b
                     break
                   end

        line_b ||= begin
                     @loop_b.next
                   rescue StopIteration
                     remain = @loop_a
                     break
                   end

        if line_a < line_b
          @dest.write(line_a)
          line_a = nil
        else
          @dest.write(line_b)
          line_b = nil
        end
      end

      @dest.write(line_a) if line_a
      @dest.write(line_b) if line_b

      loop do
        @dest.write(remain.next)
      rescue StopIteration
        break
      end

      @dest.close
    end
  end
end
