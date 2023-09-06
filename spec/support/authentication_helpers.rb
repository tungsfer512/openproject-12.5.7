#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'rack_session_access/capybara'

module AuthenticationHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  def login_as(user)
    if is_a? RSpec::Rails::FeatureExampleGroup
      # If we want to mock having finished the login process
      # we must set the user_id in rack.session accordingly
      # Otherwise e.g. calls to Warden will behave unexpectantly
      # as they will login AnonymousUser
      page.set_rack_session(user_id: user.id, updated_at: Time.now)
    end

    allow(User).to receive(:current).and_return(user)
  end

  def login_with(login, password, autologin: false, visit_signin_path: true)
    visit signin_path if visit_signin_path

    within('.user-login--form') do
      fill_in 'username', with: login
      fill_in 'password', with: password
      check I18n.t(:label_stay_logged_in) if autologin
      click_button I18n.t(:button_login)
    end
  end

  def logout
    visit signout_path
  end

  module ClassMethods
    # Sets the current user.
    #
    # Will make the return value available in the specs as +current_user+ (using
    # a let block) and treat that user as the one currently being logged in.
    #
    # @block [Proc] The user to log in.
    def current_user(&)
      let(:current_user, &)

      before { login_as current_user }
    end

    # Sets the current user.
    #
    # This is the shared_let version of +current_user+, meaning the user is
    # created only once.
    #
    # Will make the return value available in the specs as +current_user+ (using
    # a shared_let block) and treat that user as the one currently being logged
    # in.
    #
    # @block [Proc] The user to log in.
    def shared_current_user(&)
      shared_let(:current_user, &)

      before { login_as current_user }
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers
end
