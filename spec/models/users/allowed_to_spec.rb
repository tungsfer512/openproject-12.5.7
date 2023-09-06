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

require 'spec_helper'

describe User, 'allowed_to?' do
  let(:user) { build(:user) }
  let(:anonymous) { build(:anonymous) }
  let(:project) { build(:project, public: false) }
  let(:project2) { build(:project, public: false) }
  let(:role) { build(:role) }
  let(:role2) { build(:role) }
  let(:anonymous_role) { build(:anonymous_role) }
  let(:member) do
    build(:member, project:,
                   roles: [role],
                   principal: user)
  end
  let(:member2) do
    build(:member, project: project2,
                   roles: [role2],
                   principal: user)
  end
  let(:global_permission) { OpenProject::AccessControl.permissions.find { |p| p.global? } }
  let(:global_role) { build(:global_role, permissions: [global_permission.name]) }
  let(:global_member) do
    build(:global_member,
          principal: user,
          roles: [global_role])
  end

  before do
    anonymous_role.save!
    Role.non_member
    user.save!
  end

  shared_examples_for 'w/ inquiring for project' do
    let(:permission) { :add_work_packages }
    let(:final_setup_step) {}

    context 'w/ the user being admin' do
      before do
        user.update(admin: true)

        project.save

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being admin
             w/ the project being archived' do
      before do
        user.update(admin: true)
        project.update(active: false)

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being admin
             w/ the project module the permission belongs to being inactive' do
      before do
        user.update(admin: true)
        project.enabled_module_names = []

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being admin
             w/ the permission not automatically granted to admins' do
      let(:permission) { :work_package_assigned }

      before do
        user.update(admin: true)

        project.save

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/o the role having the necessary permission' do
      before do
        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/ the role having the necessary permission' do
      before do
        role.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/ the role having the necessary permission
             w/o the module being active' do
      let(:permission) { :view_news }

      before do
        role.add_permission! permission
        project.enabled_module_names = []

        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/ the role having the necessary permission
             w/ asking for a controller/action hash
             w/o the module being active' do
      let(:permission) { { controller: 'news', action: 'show' } }

      before do
        role.add_permission! permission
        project.enabled_module_names = []

        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/o the role having the necessary permission
             w/ non members having the necessary permission' do
      before do
        project.public = false

        non_member = Role.non_member
        non_member.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in the project
             w/o the role having the necessary permission
             w/ inquiring for a permission that is public' do
      let(:permission) { :view_project }

      before do
        project.public = false

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, project)
      end
    end

    context 'w/o the user being member in the project
             w/ non member being allowed the action
             w/ the project being private' do
      before do
        project.public = false
        project.save!

        non_member = Role.non_member

        non_member.add_permission! permission

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/o the user being member in the project
             w/ the project being public
             w/ non members being allowed the action' do
      before do
        project.public = true
        project.save!

        non_member = Role.non_member

        non_member.add_permission! permission

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being member in the project
             w/ the project being public
             w/ non members being allowed the action
             w/o the role being allowed the action' do
      before do
        project.public = true
        project.save!

        non_member = Role.non_member
        non_member.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being anonymous
             w/ the project being public
             w/ anonymous being allowed the action' do
      before do
        project.public = true
        project.save!

        anonymous_role.add_permission! permission

        final_setup_step
      end

      it 'is true' do
        expect(anonymous).to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being anonymous
             w/ the project being public
             w/ querying for a public permission' do
      let(:permission) { :view_project }

      before do
        project.public = true
        project.save!

        anonymous_role.save!

        final_setup_step
      end

      it 'is true' do
        expect(anonymous).to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being anonymous
             w/ requesting a controller and action allowed by multiple permissions
             w/ the project being public
             w/ anonymous being allowed the action' do
      let(:permission) { { controller: '/projects/settings/categories', action: 'show' } }

      before do
        project.public = true
        project.save!

        anonymous_role.add_permission! :manage_categories

        final_setup_step
      end

      it 'is true' do
        expect(anonymous)
          .to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being anonymous
             w/ the project being public
             w/ anonymous being not allowed the action' do
      before do
        project.public = true
        project.save!

        final_setup_step
      end

      it 'is false' do
        expect(anonymous).not_to be_allowed_to(permission, project)
      end
    end

    context 'w/ the user being a member in two projects
             w/ the user being allowed the action in both projects' do
      before do
        role.add_permission! permission
        role2.add_permission! permission

        member.save!
        member2.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, [project, project2])
      end
    end

    context 'w/ the user being a member in two projects
             w/ the user being allowed in only one project' do
      before do
        role.add_permission! permission

        member.save!
        member2.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, [project, project2])
      end
    end

    context 'w/o the user being a member in the two projects
             w/ both projects being public
             w/ non member being allowed the action' do
      before do
        non_member = Role.non_member
        non_member.add_permission! permission

        project.update(public: true)
        project2.update(public: true)

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, [project, project2])
      end
    end

    context 'w/o the user being a member in the two projects
             w/ only one project being public
             w/ non member being allowed the action' do
      before do
        non_member = Role.non_member
        non_member.add_permission! permission

        project.update(public: true)
        project2.update(public: false)

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, [project, project2])
      end
    end

    context "w/o the user being member in a project
             w/ the user having the global role
             w/ the global role having the necessary permission" do
      before do
        project.save!

        global_role.save!

        global_member.save!
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(global_permission.name, project)
      end
    end

    context 'w/ requesting a controller and action
             w/ the user being allowed the action' do
      let(:permission) { :view_wiki_pages }

      before do
        role.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user)
          .to be_allowed_to({ controller: 'wiki', action: 'show' }, project)
      end
    end

    context 'w/ requesting a controller and action allowed by multiple permissions
             w/ the user being allowed the action' do
      let(:permission) { :manage_categories }

      before do
        role.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user)
          .to be_allowed_to({ controller: 'projects', action: 'show' }, project)
      end
    end
  end

  shared_examples_for 'w/ inquiring globally' do
    let(:permission) { :add_work_packages }
    let(:final_setup_step) {}

    context 'w/ the user being admin' do
      before do
        user.admin = true
        user.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, nil, global: true)
      end
    end

    context 'w/ the user being a member in a project
             w/o the role having the necessary permission' do
      before do
        member.save!

        final_setup_step
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(permission, nil, global: true)
      end
    end

    context 'w/ the user being a member in the project
             w/ the role having the necessary permission' do
      before do
        role.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, nil, global: true)
      end
    end

    context 'w/ the user being a member in the project
             w/ inquiring for controller and action
             w/ the role having the necessary permission' do
      let(:permission) { :view_wiki_pages }

      before do
        role.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user)
          .to be_allowed_to({ controller: 'wiki', action: 'show' }, nil, global: true)
      end
    end

    context 'w/ the user being a member in the project
             w/o the role having the necessary permission
             w/ non members having the necessary permission' do
      before do
        non_member = Role.non_member
        non_member.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, nil, global: true)
      end
    end

    context 'w/o the user being a member in the project
             w/ non members being allowed the action' do
      before do
        non_member = Role.non_member
        non_member.add_permission! permission

        final_setup_step
      end

      it 'is true' do
        expect(user).to be_allowed_to(permission, nil, global: true)
      end
    end

    context "w/o the user being member in a project
             w/ the user having a global role
             w/ the global role having the necessary permission" do
      before do
        global_role.save!

        global_member.save!
      end

      it 'is true' do
        expect(user).to be_allowed_to(global_permission.name, nil, global: true)
      end
    end

    context "w/o the user being member in a project
             w/ the user having a global role
             w/o the global role having the necessary permission" do
      before do
        global_role.permissions = []
        global_role.save!

        global_member.save!
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(global_permission.name, nil, global: true)
      end
    end

    context "w/o the user being member in a project
             w/o the user having the global role
             w/ the global role having the necessary permission" do
      before do
        global_role.save!
      end

      it 'is false' do
        expect(user).not_to be_allowed_to(global_permission.name, nil, global: true)
      end
    end

    context 'w/ the user being anonymous
             w/ anonymous being allowed the action' do
      before do
        anonymous_role.add_permission! permission

        final_setup_step
      end

      it 'is true' do
        expect(anonymous).to be_allowed_to(permission, nil, global: true)
      end
    end

    context 'w/ requesting a controller and action allowed by multiple permissions
             w/ the user being a member in the project
             w/o the role having the necessary permission
             w/ non members having the necessary permission' do
      let(:permission) { :manage_categories }

      before do
        non_member = Role.non_member
        non_member.add_permission! permission

        member.save!

        final_setup_step
      end

      it 'is true' do
        expect(user)
          .to be_allowed_to({ controller: '/projects/settings/categories', action: 'show' }, nil, global: true)
      end
    end

    context 'w/ the user being anonymous
             w/ anonymous being not allowed the action' do
      before do
        final_setup_step
      end

      it 'is false' do
        expect(anonymous).not_to be_allowed_to(permission, nil, global: true)
      end
    end
  end

  context 'w/o preloaded permissions' do
    it_behaves_like 'w/ inquiring for project'
    it_behaves_like 'w/ inquiring globally'
  end

  context 'w/ preloaded permissions' do
    it_behaves_like 'w/ inquiring for project' do
      let(:final_setup_step) do
        user.preload_projects_allowed_to(permission)
      end
    end
  end
end
