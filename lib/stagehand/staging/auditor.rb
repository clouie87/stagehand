module Stagehand
  module Staging
    module Auditor
      extend self

      def incomplete_commits
        incomplete = []

        incomplete_start_operations.each do |start_operation|
          entries = records_until_match(start_operation, :asc, :operation => CommitEntry::START_OPERATION).to_a
          incomplete << [start_operation.id, entries]
        end

        incomplete_end_operations.each do |end_operation|
          entries = records_through_match(end_operation, :desc, :operation => CommitEntry::START_OPERATION).to_a
          incomplete << [entries.last.id, entries]
        end

        return incomplete.to_h
      end

      private

      # Incomplete End Operation that are not the last entry in their session
      def incomplete_end_operations
        last_entry_per_session = CommitEntry.group(:session).select('MAX(id) AS id')
        return CommitEntry.uncontained.end_operations.where.not(:id => last_entry_per_session)
      end

      # Incomplete Start on the same session as a subsequent start operation
      def incomplete_start_operations
        last_start_entry_per_session = CommitEntry.start_operations.group(:session).select('MAX(id) AS id')
        return CommitEntry.uncontained.start_operations.where.not(:id => last_start_entry_per_session)
      end

      def records_until_match(start_entry, direction, match_attributes)
        records_through_match(start_entry, direction, match_attributes)[0..-2]
      end

      def records_through_match(start_entry, direction, match_attributes)
        last_entry = next_match(start_entry, direction, match_attributes)
        return records_from(start_entry, direction).where.not("id #{exclusive_comparator(direction)} ?", last_entry)
      end

      def next_match(start_entry, direction, match_attributes)
        records_from(start_entry, direction).where.not(:id => start_entry.id).where(match_attributes).first
      end

      def records_from(start_entry, direction)
        scope = CommitEntry.where(:session => start_entry.session).where("id #{comparator(direction)} ?", start_entry.id)
        scope = scope.reverse_order if direction == :desc
        return scope
      end

      def comparator(direction)
        exclusive_comparator(direction) + '='
      end

      def exclusive_comparator(direction)
        direction == :asc ? '>' : '<'
      end
    end
  end
end
