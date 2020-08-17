# DelayedJobEs

Delayed Job Backend adapter for ElasticSearch.


The gem uses the 'elasticsearch-transport' and 'elasticsearch-api' as dependencies.

It has no other dependencies, and should be easy to integrate into any ruby based project that uses elasticsearch in any form.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'delayed_job_es'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install delayed_job_es

## Usage

### Job Class

Create a Job Class in the app/jobs folder :

```
  	class BackgroundJob < ActiveJob::Base
  
  		queue_as :default

  		## Specify the queue adapter as delayed_job_es
  		self.queue_adapter = :delayed_job_es

  		self.logger = Logger.new(nil) if Rails.env.test? 

	  	rescue_from(StandardError) do |exception|
	  		puts exception.message
	   		puts exception.backtrace.join("\n")
	  	end
  
  		def perform(args)
  			## process job here.
  		end

  	end
```

### Es Indexes

Create required ES Indexes:


```ruby
# in the rails console, (you only need to do this once)
DelayedJob::Backend::Es::Job.create_indices
```

### Job Daemon

Open a terminal window, navigate to your project and run :

	$ bundle exec rake jobs:work

This will run a job daemon(standard DelayedJob).


### Queue a Job

To queue a job, from anywhere using the job class above run (you can try this in the rails console, in another window):


```ruby
BackgroundJob.perform_later({"hello" => "world"})
```

If you look in the jobs daemon window, you will see the job getting processed.




## Development



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/delayed_job_es. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the DelayedJobEs project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/delayed_job_es/blob/master/CODE_OF_CONDUCT.md).
