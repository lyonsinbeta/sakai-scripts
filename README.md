Custom Sakai Scripts
====================

## About

I wrote this collection of scripts to help my institution manage it's course creation and maintenance.

## Dependencies

    gem install Savon
    gem install mysql2

- You could probably do this with soap4r but it's been depricated in Ruby 1.9 going forward, and even though it can be installed, Savon is just too easy to use.
- Some scripts assume access to the open source Longsight Sakai API.
- mysql2 gem is only required for the `--verify` PeopleSoft functionality.

## Use

- Scripts will either look for a .csv defined in the code or the .csv entered as an argument
- config_sample.rb needs to be renamed to config.rb and filled out
