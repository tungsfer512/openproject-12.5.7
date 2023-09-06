module Members
  class RowCell < ::RowCell
    include AvatarHelper
    include UsersHelper

    property :principal

    def member
      model
    end

    def row_css_id
      "member-#{member.id}"
    end

    def row_css_class
      "member #{principal_class_name}".strip
    end

    def name
      icon = avatar principal, size: :mini

      icon + principal_link
    end

    def mail
      return unless user?
      return if principal.pref.hide_mail

      link = mail_to(principal.mail)

      if member.principal.invited?
        i = content_tag "i", "", title: t("text_user_invited"), class: "icon icon-mail1"

        link + i
      else
        link
      end
    end

    def roles
      label = h member.roles.uniq.sort.collect(&:name).join(', ')

      if principal&.admin?
        label << tag(:br)
        label << I18n.t(:label_member_all_admin)
      end

      span = content_tag "span", label, id: "member-#{member.id}-roles"

      if may_update?
        span + role_form_cell.call
      else
        span
      end
    end

    def role_form_cell
      Members::RoleFormCell.new(
        member,
        row: self,
        params: controller.params,
        roles: table.available_roles,
        context: { controller: }
      )
    end

    def groups
      if user?
        principal.groups.map(&:name).join(", ")
      end
    end

    def status
      translate_user_status(model.principal.status)
    end

    def may_update?
      table.authorize_update
    end

    def may_delete?
      table.authorize_update
    end

    def button_links
      if may_update? && may_delete?
        [edit_link, delete_link].compact
      elsif may_delete?
        [delete_link].compact
      else
        []
      end
    end

    def edit_link
      link_to(
        op_icon('icon icon-edit'),
        '#',
        class: "toggle-membership-button #{toggle_item_class_name}",
        data: { 'toggle-target': ".#{toggle_item_class_name}" },
        title: t(:button_edit)
      )
    end

    def roles_css_id
      "member-#{member.id}-roles"
    end

    def toggle_item_class_name
      "member-#{member.id}--edit-toggle-item"
    end

    def delete_link
      if model.deletable?
        link_to(
          op_icon('icon icon-delete'),
          { controller: '/members', action: 'destroy', id: model, page: params[:page] },
          method: :delete,
          data: { confirm: delete_link_confirmation, disable_with: I18n.t(:label_loading) },
          title: delete_title
        )
      end
    end

    def delete_title
      if model.disposable?
        I18n.t(:title_remove_and_delete_user)
      else
        I18n.t(:button_remove)
      end
    end

    def delete_link_confirmation
      if !User.current.admin? && model.include?(User.current)
        t(:text_own_membership_delete_confirmation)
      end
    end

    def column_css_class(column)
      if column == :mail
        "email"
      else
        super
      end
    end

    def principal_link
      link_to principal.name, principal_show_path
    end

    def principal_class_name
      principal.model_name.singular
    end

    def principal_show_path
      case principal
      when User
        user_path(principal)
      when Group
        show_group_path(principal)
      else
        placeholder_user_path(principal)
      end
    end

    def user?
      principal.is_a?(User)
    end
  end
end
