# --copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2022 the OpenProject GmbH
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
# ++

require 'spec_helper'

describe Redmine::MenuManager::MenuHelper, type: :helper do
  before do
    # Stub the current menu item in the controller
    def @controller.current_menu_item
      :index
    end
  end

  let(:allowed_urls) { [] }
  let(:allowed_projects) { [] }

  current_user do
    build_stubbed(:user).tap do |u|
      allow(u)
        .to receive(:allowed_to?) do |queried_url, queried_project|
          allowed_urls.include?(queried_url) &&
            allowed_projects.include?(queried_project)
        end
    end
  end

  describe '#render_single_menu_node' do
    let(:item) { Redmine::MenuManager::MenuItem.new(:testing, '/test', caption: 'This is a test') }
    let(:expected) do
      <<~HTML.squish
        <a class="testing-menu-item op-menu--item-action" title="This is a test" data-qa-selector="op-menu--item-action" href="/test">
          <span class="op-menu--item-title ">
            This is a test
          </span>
        </a>
      HTML
    end

    it 'renders' do
      expect(render_single_menu_node(item))
        .to be_html_eql(expected)
    end
  end

  describe '#render_menu_node' do
    context 'for a single item' do
      let(:item) { Redmine::MenuManager::MenuItem.new(:single_node, '/test', {}) }

      let(:expected) do
        <<~HTML.squish
          <li data-name="single_node">
            <a class="single-node-menu-item op-menu--item-action" title="Single node" data-qa-selector="op-menu--item-action" href="/test">
              <span class="op-menu--item-title ">
                Single node
              </span>
            </a>
          </li>
        HTML
      end

      it 'renders' do
        expect(render_menu_node(item, nil))
          .to be_html_eql(expected)
      end
    end

    context 'for a node with nested items' do
      let(:item) do
        node = Redmine::MenuManager::MenuItem.new(:parent_node, '/test', {})
        node << Redmine::MenuManager::MenuItem.new(:child_one_node, '/test', {})
        node << Redmine::MenuManager::MenuItem.new(:child_two_node, '/test', {})
        node << Redmine::MenuManager::MenuItem.new(:child_three_node, '/test', {})
        node << Redmine::MenuManager::MenuItem.new(:child_three_inner_node, '/test', {})

        node
      end

      let(:expected) do
        <<~HTML.squish
          <li data-name="parent_node">
            <a class="parent-node-menu-item op-menu--item-action" title="Parent node" data-qa-selector="op-menu--item-action" href="/test">
              <span class="op-menu--item-title ">
                Parent node
              </span>
            </a>
            <ul class="main-menu--children">
              <li data-name="child_one_node">
                <a class="child-one-node-menu-item op-menu--item-action" title="Child one node" data-qa-selector="op-menu--item-action" href="/test">
                  <span class="op-menu--item-title ">
                    Child one node
                  </span>
                </a>
              </li>
              <li data-name="child_two_node">
                <a class="child-two-node-menu-item op-menu--item-action" title="Child two node" data-qa-selector="op-menu--item-action" href="/test">
                  <span class="op-menu--item-title ">
                    Child two node
                  </span>
                </a>
              </li>
              <li data-name="child_three_node">
                <a class="child-three-node-menu-item op-menu--item-action" title="Child three node" data-qa-selector="op-menu--item-action" href="/test">
                  <span class="op-menu--item-title ">
                    Child three node
                  </span>
                </a>
              </li>
              <li data-name="child_three_inner_node">
                <a class="child-three-inner-node-menu-item op-menu--item-action" title="Child three inner node" data-qa-selector="op-menu--item-action" href="/test">
                  <span class="op-menu--item-title ">
                    Child three inner node
                  </span>
                </a>
              </li>
            </ul>
          </li>
        HTML
      end

      it 'renders' do
        expect(render_menu_node(item, nil))
          .to be_html_eql(expected)
      end
    end

    context 'for a node with children' do
      let(:project) { build_stubbed(:project) }

      let(:allowed_projects) { [project] }
      let(:allowed_urls) { ['/test'] }

      let(:item) do
        Redmine::MenuManager::MenuItem
          .new(:parent_node,
               allowed_urls[0],
               children: Proc.new do |_p|
                 children = []
                 3.times do |time|
                   children << Redmine::MenuManager::MenuItem
                                 .new("test_child_#{time}",
                                      allowed_urls[0],
                                      {})
                 end
                 children
               end)
      end

      let(:expected) do
        <<~HTML.squish
          <li data-name="parent_node">
            <a class="parent-node-menu-item op-menu--item-action" title="Parent node" data-qa-selector="op-menu--item-action" href="/test">
              <span class="op-menu--item-title ">
                Parent node
              </span>
            </a>

            <ul class="main-menu--children unattached">
              <li>
                <a class="test-child-0-menu-item" href="/test">
                  Test child 0
                </a>
              </li>
              <li>
                <a class="test-child-1-menu-item" href="/test">
                  Test child 1
                </a>
              </li>
              <li>
                <a class="test-child-2-menu-item" href="/test">
                  Test child 2
                </a>
              </li>
            </ul>
          </li>
        HTML
      end

      it 'renders' do
        expect(render_menu_node(item, project))
          .to be_html_eql(expected)
      end
    end

    context 'for a node with nested items and children' do
      let(:project) { build_stubbed(:project) }

      let(:allowed_projects) { [project] }
      let(:allowed_urls) { ['/test'] }

      let(:item) do
        parent_node = Redmine::MenuManager::MenuItem
                        .new(:parent_node,
                             allowed_urls[0],
                             children: Proc.new do |_p|
                               children = []
                               3.times do |time|
                                 children << Redmine::MenuManager::MenuItem
                                               .new("test_child_#{time}",
                                                    allowed_urls[0],
                                                    {})
                               end
                               children
                             end)

        parent_node << Redmine::MenuManager::MenuItem
                         .new(:child_node,
                              allowed_urls[0],
                              children: Proc.new do |_p|
                                children = []
                                6.times do |time|
                                  children << Redmine::MenuManager::MenuItem
                                                .new("test_dynamic_child_#{time}",
                                                     allowed_urls[0],
                                                     {})
                                end
                                children
                              end)
        parent_node
      end

      let(:expected) do
        <<~HTML.squish
          <li data-name="parent_node">
            <a class="parent-node-menu-item op-menu--item-action" title="Parent node" data-qa-selector="op-menu--item-action" href="/test">
              <span class="op-menu--item-title ">
                Parent node
              </span>
            </a>

            <ul class="main-menu--children">
              <li data-name="child_node">
                <a class="child-node-menu-item op-menu--item-action" title="Child node" data-qa-selector="op-menu--item-action" href="/test">
                  <span class="op-menu--item-title ">
                    Child node
                  </span>
                </a>
                <ul class="main-menu--children unattached">
                  <li>
                    <a class="test-dynamic-child-0-menu-item" href="/test">
                      Test dynamic child 0
                    </a>
                  </li>
                  <li>
                    <a class="test-dynamic-child-1-menu-item" href="/test">
                      Test dynamic child 1
                    </a>
                  </li>
                  <li>
                    <a class="test-dynamic-child-2-menu-item" href="/test">
                      Test dynamic child 2
                    </a>
                  </li>
                <li>
                  <a class="test-dynamic-child-3-menu-item" href="/test">
                    Test dynamic child 3
                  </a>
                </li>
                <li>
                  <a class="test-dynamic-child-4-menu-item" href="/test">
                    Test dynamic child 4
                  </a>
                </li>
                <li>
                  <a class="test-dynamic-child-5-menu-item" href="/test">
                    Test dynamic child 5
                  </a>
                </li>
              </ul>
            </li>
          </ul>

            <ul class="main-menu--children unattached">
              <li>
                <a class="test-child-0-menu-item" href="/test">
                  Test child 0
                </a>
              </li>
              <li>
                <a class="test-child-1-menu-item" href="/test">
                  Test child 1
                </a>
              </li>
              <li>
                <a class="test-child-2-menu-item" href="/test">
                  Test child 2
                </a>
              </li>
            </ul>
          </li>
        HTML
      end

      it 'renders' do
        expect(render_menu_node(item, project))
          .to be_html_eql(expected)
      end
    end

    context 'for a node with children that is not an array' do
      let(:project) { build_stubbed(:project) }

      let(:allowed_projects) { [project] }
      let(:allowed_urls) { ['/test'] }

      let(:item) do
        Redmine::MenuManager::MenuItem
          .new(:parent_node,
               allowed_urls[0],
               children: Proc.new do |_p|
                 Redmine::MenuManager::MenuItem.new('test_child',
                                                    allowed_urls[0],
                                                    {})
               end)
      end

      it 'causes an error' do
        expect { render_menu_node(item, project) }
          .to raise_error Redmine::MenuManager::MenuError
      end
    end
  end

  describe '#first_level_menu_items_for' do
    let(:project) { build_stubbed(:project) }
    let(:allowed_projects) { [project] }
    let(:allowed_urls) { ['/test'] }

    let(:root_node) do
      instance_double(Redmine::MenuManager::TreeNode).tap do |root_node|
        allow(root_node)
          .to receive(:root)
                .and_return(root_node)

        allow(root_node)
          .to receive(:children)
                .and_return(children)
      end
    end

    let(:children) do
      (0..2).map do |i|
        Redmine::MenuManager::MenuItem.new("test_child#{i}",
                                           allowed_urls[0],
                                           {})
      end
    end

    before do
      allow(Redmine::MenuManager)
        .to receive(:items)
              .with(:test_menu)
              .and_return(root_node)
    end

    context 'when passed a block' do
      it 'yields three times' do
        expect { |b| first_level_menu_items_for(:test_menu, project, &b) }
          .to yield_successive_args(*children)
      end
    end

    context 'without a block' do
      it 'returns the child items' do
        expect(first_level_menu_items_for(:test_menu, project))
          .to eq children
      end
    end

    context 'with a child not being allowed' do
      let(:children) do
        [Redmine::MenuManager::MenuItem.new("test_child1",
                                            allowed_urls[0],
                                            {}),
         Redmine::MenuManager::MenuItem.new("test_child2",
                                            "/not_allowed",
                                            {}),
         Redmine::MenuManager::MenuItem.new("test_child3",
                                            allowed_urls[0],
                                            {})]
      end

      it 'returns only the allowed child items' do
        expect(first_level_menu_items_for(:test_menu, project))
          .to eq(children.reject { |child| child == children[1] })
      end
    end

    context 'with a child having an if proc returning true' do
      let(:children) do
        [Redmine::MenuManager::MenuItem.new("test_child1",
                                            allowed_urls[0],
                                            {}),
         Redmine::MenuManager::MenuItem.new("test_child2",
                                            allowed_urls[0],
                                            if: Proc.new { true }),
         Redmine::MenuManager::MenuItem.new("test_child3",
                                            allowed_urls[0],
                                            {})]
      end

      it 'returns only the allowed child items' do
        expect(first_level_menu_items_for(:test_menu, project))
          .to eq children
      end
    end

    context 'with a child having an if proc returning false' do
      let(:children) do
        [Redmine::MenuManager::MenuItem.new("test_child1",
                                            allowed_urls[0],
                                            {}),
         Redmine::MenuManager::MenuItem.new("test_child2",
                                            allowed_urls[0],
                                            if: Proc.new { false }),
         Redmine::MenuManager::MenuItem.new("test_child3",
                                            allowed_urls[0],
                                            {})]
      end

      it 'returns only the allowed child items' do
        expect(first_level_menu_items_for(:test_menu, project))
          .to eq(children.reject { |child| child == children[1] })
      end
    end
  end
end
