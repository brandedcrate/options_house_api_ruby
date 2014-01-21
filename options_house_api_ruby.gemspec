#--  -*- mode: ruby; encoding: utf-8 -*-
# Copyright: Copyright (c) 2013 Konstantin Dzreev.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'rubygems'

current_folder = File.dirname(__FILE__)
require File.expand_path('./lib/options_house_api_version', current_folder)

Gem::Specification.new do |spec|
  spec.name                  = 'options_house_api_ruby'
  spec.version               = OptionsHouse::VERSION::STRING
  spec.authors               = ['Konstantin Dzreev']
  spec.email                 = 'k.dzreyev@gmail.com'
  spec.summary               = 'The gem implements a ruby interface to OpenHouse API'
  spec.required_ruby_version = '>= 1.8.7'
  spec.require_path          = 'lib'
  spec.description           = File.read("#{current_folder}/README.md")

  spec.add_dependency 'json', '>= 1.0.0'

  candidates      = Dir.glob('{lib,spec}/**/*')
  candidates     += ['LICENSE', 'README.md', 'Gemfile', 'options_house_api_ruby.gemspec']
  spec.files      = candidates.sort
  spec.test_files = Dir.glob('spec/**/*')
end
