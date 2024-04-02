# Parasort

Parallel sort

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parasort'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install parasort

## Usage

use as lib

```ruby
require 'parasort'

Parasort.each(File.foreach(...)) do |line|
  # ...
end
```

use as cli

```sh
seq 1 10 | parasort

# or
parasort file1 file2
```
