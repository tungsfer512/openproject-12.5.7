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

module Pages
  class Page
    include Capybara::DSL
    include Capybara::RSpecMatchers
    include RSpec::Matchers
    include OpenProject::StaticRouting::UrlHelpers

    def current_page?
      URI.parse(current_url).path == path
    end

    def visit!
      raise 'No path defined' unless path

      visit path

      self
    end

    def reload!
      page.driver.browser.navigate.refresh
    end

    def accept_alert_dialog!
      alert_dialog.accept if selenium_driver?
    end

    def dismiss_alert_dialog!
      alert_dialog.dismiss if selenium_driver?
    end

    def alert_dialog
      page.driver.browser.switch_to.alert
    end

    def has_alert_dialog?
      if selenium_driver?
        begin
          page.driver.browser.switch_to.alert
        rescue ::Selenium::WebDriver::Error::NoSuchAlertError
          false
        end
      end
    end

    def selenium_driver?
      Capybara.current_session.driver.is_a?(Capybara::Selenium::Driver)
    end

    def set_items_per_page!(number)
      Setting.per_page_options = "#{number}, 50, 100"
    end

    def expect_current_path(query_params = nil)
      expected_path = path
      expected_path += "?#{query_params}" if query_params

      expect(page).to have_current_path expected_path, wait: 10
    end

    def expect_toast(message:, type: :success)
      if toast_type == :angular
        expect(page).to have_selector(".op-toast.-#{type}", text: message, wait: 20)
      elsif type == :error
        expect(page).to have_selector(".errorExplanation", text: message)
      elsif type == :success
        expect(page).to have_selector(".flash.notice", text: message)
      else
        raise NotImplementedError
      end
    end

    def expect_and_dismiss_toaster(message: nil, type: :success)
      expect_toast(type:, message:)
      dismiss_toaster!
      expect_no_toaster(type:, message:)
    end

    def dismiss_toaster!
      if toast_type == :angular
        page.find('.op-toast--close').click
      else
        page.find('.flash .icon-close').click
      end
    end

    def expect_no_toaster(type: :success, message: nil)
      if type.nil?
        expect(page).not_to have_selector(".op-toast")
      else
        expect(page).not_to have_selector(".op-toast.-#{type}", text: message)
      end
    end

    def drag_and_drop_list(from:, to:, elements:, handler:)
      # Wait a bit because drag & drop in selenium is easily offended
      sleep 1

      list = page.all(elements)
      source = list[from]
      target = list[to]

      scroll_to_element(source)
      source.hover

      page
        .driver
        .browser
        .action
        .move_to(source.native)
        .click_and_hold(source.find(handler).native)
        .perform

      ## Hover over each item to be sure,
      # that the dragged element is reduced to the minimum height.
      # Thus we can afterwards drag to the correct position.
      list.each do |item|
        next if item == source

        page
          .driver
          .browser
          .action
          .move_to(item.native)
          .perform
      end

      sleep 2

      scroll_to_element(target)

      page
        .driver
        .browser
        .action
        .move_to(target.native)
        .release
        .perform

      # Wait a bit because drag & drop in selenium is easily offended
      sleep 1
    end

    def path
      nil
    end

    def toast_type
      :angular
    end
  end
end
