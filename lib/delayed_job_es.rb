require "delayed_job_es/version"
require 'delayed/backend/es'
require 'delayed_job'
require 'elasticsearch'
require 'json'

Delayed::Worker.backend = Delayed::Backend::Es::Job

module DelayedJobEs
  class Error < StandardError; end
  # Your code goes here...
  class DummyJob
  	
  	attr_accessor :arguments
  	
  	def initialize(args={})
  		@arguments = args[:arguments]
  	end

  	def perform
  		puts "Peforming dummyjob at #{Time.now}, with arguments : #{@arguments}"
  	end
  
  end

end
