module Stagehand
  module Database
    extend self

    @@connection_name_stack = [Rails.env.to_sym]

    def connected_to_production?
      current_connection_name == Configuration.production_connection_name
    end

    def connected_to_staging?
      current_connection_name == Configuration.staging_connection_name
    end

    def staging_connection
      StagingProbe.connection
    end

    def production_connection
      ProductionProbe.connection
    end

    def with_connection(connection_name)
      different = !Configuration.ghost_mode? && current_connection_name != connection_name.to_sym

      @@connection_name_stack.push(connection_name.to_sym)
      Rails.logger.debug "Connecting to #{current_connection_name}"
      connect_to(current_connection_name) if different

      yield
    ensure
      @@connection_name_stack.pop
      Rails.logger.debug "Restoring connection to #{current_connection_name}"
      connect_to(current_connection_name) if different
    end

    def set_connection_for_model(model, connection_name)
      connect_to(connection_name, model) unless Configuration.ghost_mode?
    end

    private

    def connect_to(connection_name, model = ActiveRecord::Base)
      model.establish_connection(connection_name)
    end

    def current_connection_name
      @@connection_name_stack.last
    end


    # CLASSES

    class Probe < ActiveRecord::Base
      self.abstract_class = true
      class_attribute :connection_name

      def self.connection
        @connected ||= establish_connection(connection_name)
        super
      end
    end

    class StagingProbe < Probe
      self.abstract_class = true
      self.connection_name = Configuration.staging_connection_name
    end

    class ProductionProbe < Probe
      self.abstract_class = true
      self.connection_name = Configuration.production_connection_name
    end
  end
end
