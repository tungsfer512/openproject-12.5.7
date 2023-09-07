module Components::Autocompleter
  module NgSelectAutocompleteHelpers
    def search_autocomplete(element, query:, results_selector: nil, wait_dropdown_open: true)
      SeleniumHubWaiter.wait
      # Open the element
      element.click

      # Wait for dropdown to open
      ng_find_dropdown(element, results_selector:) if wait_dropdown_open

      # Wait for autocompleter options to be loaded (data fetching is debounced by 250ms after creation or typing)
      expect(element).not_to have_selector('.ng-spinner-loader')

      # Insert the text to find
      within(element) do
        ng_enter_query(element, query)
      end
      sleep(0.5)

      # Find the open dropdown
      dropdown_list = ng_find_dropdown(element, results_selector:)
      scroll_to_element(dropdown_list)
      dropdown_list
    end

    def ng_find_dropdown(element, results_selector: nil)
      if results_selector
        results_selector = "#{results_selector} .ng-dropdown-panel" if results_selector == 'body'
        page.find(results_selector)
      else
        within(element) do
          page.find('ng-select .ng-dropdown-panel')
        end
      end
    end

    ##
    # Insert the query, typing
    def ng_enter_query(element, query)
      input = element.find('input[type=text]', visible: :all).native
      input.clear

      query = query.to_s

      if query.length > 1
        # Send all keys, and then with a delay the last one
        # to emulate normal typing
        input.send_keys(query[0..-2])
        sleep 0.2
        input.send_keys(query[-1])
      else
        input.send_keys(query)
      end
    end

    ##
    # Get the ng_select input element
    def ng_select_input(from_element)
      from_element.find('.ng-input input')
    end

    ##
    # clear the ng select field
    def ng_select_clear(from_element)
      from_element.find('.ng-clear-wrapper', visible: :all).click
    end

    def select_autocomplete(element, query:, select_text: nil, results_selector: nil, wait_dropdown_open: true)
      target_dropdown = search_autocomplete(element,
                                            query:,
                                            results_selector:,
                                            wait_dropdown_open:)

      ##
      # If a specific select_text is given, use that to locate the match,
      # otherwise use the query
      text = select_text.presence || query

      # click the element to select it
      target_dropdown.find('.ng-option', text:, match: :first, wait: 15).click
    end
  end
end
