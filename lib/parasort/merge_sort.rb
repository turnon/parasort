module Parasort
  module MergeSort
    class << self
      def all(enums)
        enum_a, enum_b = split(enums)
        @merged = merge(enum_a, enum_b)
      end

      private

      def merge(enum_a, enum_b)
        Enumerator.new do |e|
          a = nil
          b = nil
          remain = nil

          loop do
            a ||= begin
                    enum_a.next
                  rescue StopIteration
                    remain = enum_b
                    break
                  end

            b ||= begin
                    enum_b.next
                  rescue StopIteration
                    remain = enum_a
                    break
                  end

            if a < b
              e.yield(a)
              a = nil
            else
              e.yield(b)
              b = nil
            end
          end

          e.yield(a) if a
          e.yield(b) if b

          loop do
            e.yield(remain.next)
          rescue StopIteration
            break
          end
        end
      end

      def split(enums)
        case enums.size
        when 0
          [[].to_enum, [].to_enum]
        when 1
          [enums[0], [].to_enum]
        when 2
          enums
        else
          [
            all(enums[0...(enums.size / 2)]),
            all(enums[(enums.size / 2)..-1])
          ]
        end
      end
    end
  end
end
