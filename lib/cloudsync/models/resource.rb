require 'digest/md5'

# Represents a local file asset
module Cloudsync
  module Models
    class Resource < ActiveRecord::Base
      
      scope :pending_jobs, select(:id).where(:queued => true)
      
      # Builds a resource for the backup index from a file
      # @param [File] a file object
      # @param [String] the name of the file on the remote disk
      # @returns [Resource] a new Resource instance that with a queued status
      def self.create_from_file_and_name(file, name)
        is_dir = File.directory?(file)
        create(:filename => name,
               :size => file.size,
               :last_modified => file.ctime,
               :add_date => DateTime.now,
               :queued => !is_dir,
               :checksum => is_dir ? nil : Digest::MD5.file(file).to_s,
               :is_directory => is_dir)
      end
      
      # Yields a Models::Resource object that needs to be synchronized
      def self.pending_sync_groups(response_size, &block)
        qry = lambda { Resource.where(:queued => true) }
        chunked_groups(qry, response_size) { |chunk| yield chunk }
      end
      
      # Returns groups of file resources ordered by name
      # @param [Integer] the number of records to return per chunk
      # @yields [Array] instances of Models::Resource
      def self.ordered_groups(group_size = 10)
        qry = lambda { Resource.order(:filename) }
        chunked_groups(qry, group_size) { |chunk| yield chunk }
      end
      
      def self.chunked_groups(qry_func, chunk_size)
        num_results = Resource.count
        offset = 0
        pages = (num_results/chunk_size.to_f).ceil
        pages.times do |i|
          response = qry_func.call().limit(chunk_size).offset(i*chunk_size)
          yield response
        end
      end
      
      # Compares a file asset to the index to deterimine whether the file needs to be updated
      # @param [String] a path to a file or directory
      # @returns [Boolean] whether the file and index are in sync with each other
      def synchronized?(file)
        if File.exists? file
          return true if File.directory? file
          return Digest::MD5.file(file).to_s == self.checksum
        end
        false
      end
      
      def start_progress
        update_attribute :in_progress, true
      end
      
      def update_success
        update_attributes :in_progress => false, 
                          :last_synchronized => DateTime.now, 
                          :queued => false,
                          :times_failed => 0
      end
      
      def update_failure
        num_times_failed = times_failed + 1
        will_requeue = (num_times_failed < Cloudsync::Application.config.max_upload_retries)
        update_attributes :times_failed => num_times_failed, :in_progress => false, :queued => will_requeue
      end
      
      def abs_path
        File.join(Models::AppSetting.backup_path, filename)
      end

    end
  end
end