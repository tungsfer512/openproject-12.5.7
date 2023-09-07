// -- copyright
// OpenProject is an open source project management software.
// Copyright (C) 2012-2023 the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  Component, ElementRef, OnInit, ViewChild,
} from '@angular/core';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { HalResourceService } from 'core-app/features/hal/services/hal-resource.service';
import { States } from 'core-app/core/states/states.service';
import { filter, takeUntil } from 'rxjs/operators';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import {
  ICKEditorType,
} from 'core-app/shared/components/editor/components/ckeditor/ckeditor-setup.service';
import { OpCkeditorComponent } from 'core-app/shared/components/editor/components/ckeditor/op-ckeditor.component';
import { componentDestroyed } from '@w11k/ngx-componentdestroyed';
import { UntilDestroyedMixin } from 'core-app/shared/helpers/angular/until-destroyed.mixin'; import {
  ICKEditorContext,
  ICKEditorInstance,
} from 'core-app/shared/components/editor/components/ckeditor/ckeditor.types';

export const ckeditorAugmentedTextareaSelector = 'ckeditor-augmented-textarea';

@Component({
  selector: ckeditorAugmentedTextareaSelector,
  templateUrl: './ckeditor-augmented-textarea.html',
})
export class CkeditorAugmentedTextareaComponent extends UntilDestroyedMixin implements OnInit {
  public textareaSelector:string;

  public previewContext:string;

  // Which template to include
  public $element:JQuery;

  public formElement:JQuery;

  public wrappedTextArea:JQuery;

  public $attachmentsElement:JQuery;

  // Remember if the user changed
  public changed = false;

  public inFlight = false;

  public initialContent:string;

  public resource?:HalResource;

  public context:ICKEditorContext;

  public macros:boolean;

  public text = {
    attachments: this.I18n.t('js.label_attachments'),
  };

  // Reference to the actual ckeditor instance component
  @ViewChild(OpCkeditorComponent, { static: true }) private ckEditorInstance:OpCkeditorComponent;

  private attachments:HalResource[];

  private isEditing = false;

  constructor(
    protected elementRef:ElementRef,
    protected pathHelper:PathHelperService,
    protected halResourceService:HalResourceService,
    protected Notifications:ToastService,
    protected I18n:I18nService,
    protected states:States,
  ) {
    super();
  }

  ngOnInit() {
    this.$element = jQuery(this.elementRef.nativeElement);

    // Parse the attribute explicitly since this is likely a bootstrapped element
    this.textareaSelector = this.$element.attr('textarea-selector')!;
    this.previewContext = this.$element.attr('preview-context')!;
    this.macros = this.$element.attr('macros') !== 'false';
    const editorType = (this.$element.attr('editor-type') || 'full') as ICKEditorType;

    // Parse the resource if any exists
    const source = this.$element.data('resource');
    this.resource = source ? this.halResourceService.createHalResource(source, true) : undefined;

    this.formElement = this.$element.closest('form');
    this.wrappedTextArea = this.formElement.find(this.textareaSelector);
    this.wrappedTextArea
      .removeAttr('required')
      .hide();
    this.initialContent = this.wrappedTextArea.val() as string;

    this.$attachmentsElement = this.formElement.find('#attachments_fields');
    this.context = {
      type: editorType,
      resource: this.resource,
      previewContext: this.previewContext,
    };
    if (!this.macros) {
      this.context.macros = 'none';
    }
  }

  ngOnDestroy() {
    super.ngOnDestroy();
    this.formElement.off('submit.ckeditor');
  }

  public markEdited() {
    window.OpenProject.pageWasEdited = true;
  }

  public setup(editor:ICKEditorInstance) {
    // Have a hacky way to access the editor from outside of angular.
    // This is e.g. employed to set the text from outside to reuse the same editor for different languages.
    this.$element.data('editor', editor);

    if (this.resource && this.resource.attachments) {
      this.setupAttachmentAddedCallback(editor);
      this.setupAttachmentRemovalSignal(editor);
    }

    // Listen for form submission to set textarea content
    this.formElement.on('submit.ckeditor change.ckeditor', () => {
      try {
        const data = this.ckEditorInstance.getRawData();
        this.wrappedTextArea.val(data);
      } catch (e) {
        console.error(`Failed to save CKEditor body to textarea: ${e}.`);
        this.Notifications.addError(e || this.I18n.t('js.error.internal'));

        // Avoid submission of the form
        return false;
      }

      this.addUploadedAttachmentsToForm();

      // Continue with submission
      return true;
    });

    this.setLabel();

    return editor;
  }

  private setupAttachmentAddedCallback(editor:ICKEditorInstance) {
    editor.model.on('op:attachment-added', () => {
      this.states.forResource(this.resource!)!.putValue(this.resource);
    });
  }

  private setupAttachmentRemovalSignal(editor:ICKEditorInstance) {
    this.attachments = _.clone(this.resource!.attachments.elements);

    this.states.forResource(this.resource!)!.changes$()
      .pipe(
        takeUntil(componentDestroyed(this)),
        filter((resource) => !!resource),
      ).subscribe((resource) => {
        const missingAttachments = _.differenceBy(this.attachments,
          resource!.attachments.elements,
          (attachment:HalResource) => attachment.id);

        const removedUrls = missingAttachments.map((attachment) => attachment.downloadLocation.href);

        if (removedUrls.length) {
          editor.model.fire('op:attachment-removed', removedUrls);
        }

        this.attachments = _.clone(resource!.attachments.elements);
      });
  }

  private setLabel() {
    const textareaId = this.textareaSelector.substring(1);
    const label = jQuery(`label[for=${textareaId}]`);

    const ckContent = this.$element.find('.ck-content');

    ckContent.attr('aria-label', null);
    ckContent.attr('aria-labelledby', textareaId);

    label.click(() => {
      ckContent.focus();
    });
  }

  private addUploadedAttachmentsToForm() {
    if (!this.resource || !this.resource.attachments || this.resource.id) {
      return;
    }

    const takenIds = this.$attachmentsElement.find("input[type='file']").map((index, input) => {
      const match = /attachments\[(\d+)\]\[(?:file|id)\]/.exec((input.getAttribute('name') || ''));

      if (match) {
        return parseInt(match[1]);
      }
      return 0;
    });

    const maxValue:number = takenIds.toArray().sort().pop() || 0;

    const addedAttachments = this.resource.attachments.elements || [];

    jQuery.each(addedAttachments, (index:number, attachment:HalResource) => {
      this.$attachmentsElement.append(`<input type="hidden" name="attachments[${maxValue + index + 1}][id]" value="${attachment.id}">`);
    });
  }
}
