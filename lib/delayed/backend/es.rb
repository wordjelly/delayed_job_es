require 'delayed_job'
require 'elasticsearch'
require 'json'

## Delayed::Backend::Es::Job.create_index!
## so we need to write a spec here.
module Delayed
	module Backend
		module Es
			class Job
				attr_accessor :id
				attr_accessor :version
		        attr_accessor :priority
		        attr_accessor :attempts
		        attr_accessor :handler
		        attr_accessor :last_error
		        attr_accessor :run_at
		        attr_accessor :locked_at
		        attr_accessor :locked_by
		        attr_accessor :failed_at
		        attr_accessor :queue

				include Delayed::Backend::Base
				
				INDEX_NAME = "delayed-jobs"
				DOCUMENT_TYPE = "job"
				
				################################################
				##
				##
				## elasticsearch client
				##
				##
				################################################
				cattr_accessor :client

		        def self.get_client
		        	if Elasticsearch::Persistence.client
		        		puts "got persistence client, using it."
		        		puts "its settings are/"
		        		puts Elasticsearch::Persistence.client
		        		Elasticsearch::Persistence.client
		        	else
		        		puts "----- returning the default client --------- "
		        		client ||= Elasticsearch::Client.new
		        		client
		        	end
		        end

		        def self.mappings
					{
						payload_object: {
							type: 'object'
						},
						locked_at: {
							type: 'date',
							format: 'yyyy-MM-dd HH:mm:ss'
						},
						failed_at: {
							type: 'date',
							format: 'yyyy-MM-dd HH:mm:ss'
						},
						priority: {
							type: 'integer'
						},
						attempts: {
							type: 'integer'
						},
						queue: {
							type: 'keyword'
						},
						handler: {
							type: 'keyword'
						},
						locked_by: {
							type: 'keyword'
						},
						last_error: {
							type: 'keyword'
						},
						run_at: {
							type: 'date',
							format: 'yyyy-MM-dd HH:mm:ss'
						}
					}
				end	

				def self.create_index
					response = get_client.indices.create :index => INDEX_NAME, :body => {
						mappings: {DOCUMENT_TYPE => { :properties =>  mappings}}
					}
				end

				def self.delete_index
					response = get_client.indices.delete :index => INDEX_NAME
				end

				def self.create_indexes
					delete_index
					create_index
				end

		        def initialize(hash = {})
		          self.attempts = 0
		          self.priority = 0
		          self.id = SecureRandom.hex(5)
		          hash.each { |k, v| send(:"#{k}=", v) }
		        end

		        ## CALLING 'ALL' IS NEVER A GOOD IDEA
		        ## MEMORY LEAKS ALWAYS BEGIN LIKE THIS!!!
		        ## stub to call 10 jobs.
		        def self.all
		          search_response = get_client.search :index =>INDEX_NAME, :type => DOCUMENT_TYPE, :body => {:size => 10, :query => {match_all: {}}}
		          search_response["hits"]["hits"].map{|c|
		          	new(c["_source"].merge("id" => c["_id"]))
		          }
		        end

		        def self.count
		          get_client.count index: INDEX_NAME
		        end

		        def self.delete_all
		          create_indexes
		        end

		        def self.create(attrs = {})
		          new(attrs).tap do |o|
		            o.save
		          end
		        end

		        def self.create!(*args)
		          create(*args)
		        end

		        ##################################
		        ##
		        ##
		        ## USES ES SCROLL API
		        ##
		        ##
		        ##################################
		        def self.clear_locks!(worker_name)
		        	scroll_id = nil
		        	execution_count = 0
		        	while true
		        		begin
			        		response = nil
							# Display the initial results
							#puts "--- BATCH 0 -------------------------------------------------"
							#puts r['hits']['hits'].map { |d| d['_source']['title'] }.inspect
							if scroll_id.blank?
								response = get_client.search index: INDEX_NAME, scroll: '4m', body: {_source: false, query: {term: {locked_by: worker_name}}}
							else
								response = get_client.scroll scroll_id: scroll_id, scroll: '4m'
							end
							
							scroll_id = response['_scroll_id']

							job_ids = response['hits']['hits'].map{|c| c['_id']}
						 	
						  	break if job_ids.blank?

						  	bulk_array = []
						  	
						  	script = 
							{
								:lang => "painless",
								:params => {
									
								},
								:source => '''
									ctx._source.locked_at = null;
									ctx._source.locked_by = null;
								'''
							}

						  	job_ids.each do |jid|

						  		bulk_array << {
						  			_update: {
						  				_index: INDEX_NAME,
						  				_type: DOCUMENT_TYPE,
						  				_id: jid,
						  				data: {
							  				script: script, 
							  				scripted_upsert: false,
							  				upsert: {}
						  				}
						  			}
						  		}

						  	end

						  	bulk_response = get_client.bulk body: bulk_array

						  	execution_count +=1	

						  	break if execution_count > 10
					  	rescue => e
					  		puts "error clearing locks--->"
					  		puts e.to_s
					  		break
					  	end
		        	end
		        end

		        # Find a few candidate jobs to run (in case some immediately get locked by others).
		        def self.find_available(worker_name, limit = 5, max_run_time = Worker.max_run_time) 
		        	#puts "max run time is:"
		        	#puts Worker.max_run_time
		        	right_now = Time.now
		        	#####################################################
					##
					##
					## THE BASE QUERY
					## translated into human terms
					## any job where
					## 1. run_at is less than the current time
					## AND
					## 2. locked_by : current_worker OR locked_At : nil OR locked_at < (time_now - max_run_time)
					## AND
					## 3. failed_at : nil
					## AND
					## OPTIONAL ->
					## priority queries
					## OPTIONAL ->
					## queue name.
					##
					##
					#####################################################

					query = {
						bool: {
							must: [
								{
									range: {
										run_at: {
											lte: right_now.strftime("%Y-%m-%d %H:%M:%S")
										}
									}
								},
								{
									bool: {
										should: [
											{
												term: {
													locked_by: Worker.name
												}
											},
											{
												bool: {
													must_not: [
														{
															exists: {
																field: "locked_at"
															}
														}
													]
												}
											},
											{
												range: {
													locked_at: {
														lte: (right_now - max_run_time).strftime("%Y-%m-%d %H:%M:%S")
													}
												}
											}
										]
									}
								}
							],
							must_not: [
								{
									exists: {
										field: "failed_at"
									}
								}
							]
						}
					}

					################################################
					##
					##
					## ADD PRIORITY CLAUSES
					##
					##
					################################################
					if Worker.min_priority
						query[:bool][:must] << {
							range: {
								priority: {
									gte: Worker.min_priority.to_i
								}
							}
						}
					end

					if Worker.max_priority
						query[:bool][:must] << {
							range: {
								priority: {
									lte: Worker.max_priority.to_i
								}
							}
						}
					end


					##############################################
					##
					##
					## QUEUES IF SPECIFIED.
					##
					##
					##############################################
					if Worker.queues.any?
						query[:bool][:must] << {
							terms: {
								queue: Worker.queues
							}
						}
					end


					#############################################
					##
					##
					## SORT
					##
					##
					############################################
					sort = [
						{"locked_by" => "desc"},
						{"priority" => "asc"},
						{"run_at" => "asc"}
					]

					##puts "find available jobs query is:"
					##puts JSON.pretty_generate(query)

					search_response = get_client.search :index => INDEX_NAME, :type => DOCUMENT_TYPE,
						:body => {
							version: true,
							size: limit,
							sort: sort,
							query: query
						}
					

					puts "search_response is"
					puts search_response["hits"]["hits"]
					## it would return the first hit.
					search_response["hits"]["hits"].map{|c|
						k = new(c["_source"])
						k.id = c["_id"]
						k.version = c["_version"]
						k
					}

		        end

		        # Lock this job for this worker.
		        # Returns true if we have the lock, false otherwise.
		        def lock_exclusively!(_max_run_time, worker)
		          #puts "called lock exclusively ------------------------>"
		          
		          script = 
					{
						:lang => "painless",
						:params => {
							:locked_at => self.class.db_time_now.strftime("%Y-%m-%d %H:%M:%S"),
							:locked_by => worker,
							:version => self.version
						},
						:source => '''
							if(ctx._version == params.version){
								ctx._source.locked_at = params.locked_at;
								ctx._source.locked_by = params.locked_by;
							}
							else{
								ctx.op = "none";
							}
						'''
					}

					puts "Script is"
					puts JSON.pretty_generate(script)


					#begin
					response = self.class.get_client.update(index: INDEX_NAME, type: DOCUMENT_TYPE, id: self.id.to_s, body: {
						:script => script,
						:scripted_upsert => false,
						:upsert => {}	
					})

					## if this returns no-op chec,
					puts "lock response:"
					puts response.to_s
					

					return response["result"] == "updated"
		          
		        end

		        def self.db_time_now
		          Time.current
		        end

		        def update_attributes(attrs = {})
		          attrs.each { |k, v| send(:"#{k}=", v) }
		          save
		        end

		        def destroy
		          # gotta do this.
		          #puts "Calling destroy"
		          self.class.get_client.delete :index => INDEX_NAME, :type => DOCUMENT_TYPE, :id => self.id.to_s
		        end

		        def json_representation
		        	if self.respond_to? "as_json"
		        		as_json.except("payload_object").except(:payload_object)
		        	else
		        		puts "payload object is ----------->"
		        		puts self.payload_object
		        		attributes = {}
		        		self.class.mappings.keys.each do |attr|
		        			if attr.to_s == "payload_object"
		        				## this object has to be serialized.
		        				## 
		        			else
		        				attributes[attr] = self.send(attr)
		        			end
		        		end
		        		JSON.generate(attributes)
		        	end
		        end

		        def save
		          #puts "Came to save --------------->"
		          self.run_at ||= Time.current.strftime("%Y-%m-%d %H:%M:%S")
		          ## so here you do the actual saving.
		          #Elasticsearch::Client.gateway.
		          #puts "object as json -------------->"
		          #puts json_representation
		          save_response = self.class.get_client.index :index => INDEX_NAME, :type => DOCUMENT_TYPE, :body => json_representation, :id => self.id.to_s
		          #puts "save response is: #{save_response}"
		          self.class.all << self unless self.class.all.include?(self)
		          true
		        end

		        def save!
		          save
		        end

		        def reload
		          #puts "called reload job---------------->"
		          object = self.class.get_client.get :id => self.id, :index => INDEX_NAME, :type => DOCUMENT_TYPE
		          k = self.class.new(object["_source"])
		          k.id = object["_id"]
		          k
		        end
			end
		end
	end
end