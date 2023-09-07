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

import { HalResourceNotificationService } from 'core-app/features/hal/services/hal-resource-notification.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { ToastService } from 'core-app/shared/components/toaster/toast.service';
import { ConfigurationService } from 'core-app/core/config/configuration.service';
import { HttpErrorResponse } from '@angular/common/http';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { OpenProjectDirectFileUploadService } from 'core-app/core/file-upload/op-direct-file-upload.service';
import { OpenProjectFileUploadService, UploadFile } from 'core-app/core/file-upload/op-file-upload.service';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { AttachmentCollectionResource } from 'core-app/features/hal/resources/attachment-collection-resource';
import isNewResource from 'core-app/features/hal/helpers/is-new-resource';

type Constructor<T = {}> = new (...args:any[]) => T;

export function Attachable<TBase extends Constructor<HalResource>>(Base:TBase) {
  return class extends Base {
    public attachments:AttachmentCollectionResource;

    private ToastService:ToastService;

    private halNotification:HalResourceNotificationService;

    private opFileUpload:OpenProjectFileUploadService;

    private opDirectFileUpload:OpenProjectDirectFileUploadService;

    private pathHelper:PathHelperService;

    private apiV3Service:ApiV3Service;

    private config:ConfigurationService;

    /**
     * Can be used in the mixed in class to disable
     * attempts to upload attachments right away.
     */
    private attachmentsBackend:boolean|null;

    /**
     * Return whether the user is able to upload an attachment.
     *
     * If either the `addAttachment` link is provided or the resource is being created,
     * adding attachments is allowed.
     */
    public get canAddAttachments():boolean {
      return !!this.$links.addAttachment || isNewResource(this);
    }

    /**
     *
     */
    public get hasAttachments():boolean {
      return _.get(this.attachments, 'elements.length', 0) > 0;
    }

    /**
     * Try to find an existing file's download URL given its filename
     * @param file
     */
    public lookupDownloadLocationByName(file:string):string|null {
      if (!(this.attachments && this.attachments.elements)) {
        return null;
      }

      const match = _.find(this.attachments.elements, (res:HalResource) => res.name === file);
      return _.get(match, 'staticDownloadLocation.href', null);
    }

    /**
     * Remove the given attachment either from the pending attachments or from
     * the attachment collection, if it is a resource.
     *
     * Removing it from the elements array assures that the view gets updated immediately.
     * If an error occurs, the user gets notified and the attachment is pushed to the elements.
     */
    public removeAttachment(attachment:any):Promise<any> {
      _.pull(this.attachments.elements, attachment);

      if (attachment.$isHal) {
        return attachment.delete()
          .then(() => {
            if (this.attachmentsBackend) {
              this.updateAttachments();
            } else {
              this.attachments.count = Math.max(this.attachments.count - 1, 0);
            }
          })
          .catch((error:any) => {
            this.halNotification.handleRawError(error, this as any);
            this.attachments.elements.push(attachment);
          });
      }
      return Promise.resolve();
    }

    /**
     * Get updated attachments from the server and push the state
     *
     * Return a promise that returns the attachments. Reject, if the work package has
     * no attachments.
     */
    public updateAttachments():Promise<HalResource> {
      return this
        .attachments
        .updateElements()
        .then(() => {
          this.updateState();
          return this.attachments;
        });
    }

    /**
     * Upload the given attachments, update the resource and notify the user.
     * Return an updated AttachmentCollectionResource.
     */
    public uploadAttachments(files:UploadFile[]):Promise<string|{ response:HalResource, uploadUrl:string }[]> {
      const { uploads, finished } = this.performUpload(files);

      const message = I18n.t('js.label_upload_notification');
      const notification = this.ToastService.addAttachmentUpload(message, uploads);

      return finished
        .then((result:{ response:HalResource, uploadUrl:string }[]) => {
          setTimeout(() => this.ToastService.remove(notification), 700);

          this.attachments.count += result.length;
          result.forEach((r) => {
            this.attachments.elements.push(r.response);
          });
          this.updateState();

          return result;
        })
        .catch((error:HttpErrorResponse) => {
          let message:undefined|string;
          console.error('Error while uploading: %O', error);

          if (error.error instanceof ErrorEvent) {
            // A client-side or network error occurred.
            message = this.I18n.t('js.error_attachment_upload', { error });
          } else if (_.get(error, 'error._type') === 'Error') {
            message = error.error.message;
          } else {
            // The backend returned an unsuccessful response code.
            message = error.error;
          }

          this.halNotification.handleRawError(message);
          return message || I18n.t('js.error.internal');
        });
    }

    private performUpload(files:UploadFile[]) {
      let href:string = this.directUploadURL || '';

      if (href) {
        return this.opDirectFileUpload.uploadAndMapResponse(href, files);
      } if (isNewResource(this) || !this.id || !this.attachmentsBackend) {
        href = this.apiV3Service.attachments.path;
      } else {
        href = this.addAttachment.$link.href;
      }

      return this.opFileUpload.uploadAndMapResponse(href, files);
    }

    private get directUploadURL():string|null {
      if (this.$links.prepareAttachment) {
        return this.$links.prepareAttachment.href;
      }

      if (isNewResource(this)) {
        return this.config.prepareAttachmentURL;
      }
      return null;
    }

    private updateState() {
      if (this.state) {
        this.state.putValue(this as any);
      }
    }

    public $initialize(source:any) {
      if (!this.ToastService) {
        this.ToastService = this.injector.get(ToastService);
      }
      if (!this.halNotification) {
        this.halNotification = this.injector.get(HalResourceNotificationService);
      }
      if (!this.opFileUpload) {
        this.opFileUpload = this.injector.get(OpenProjectFileUploadService);
      }
      if (!this.opDirectFileUpload) {
        this.opDirectFileUpload = this.injector.get(OpenProjectDirectFileUploadService);
      }
      if (!this.config) {
        this.config = this.injector.get(ConfigurationService);
      }
      if (!this.pathHelper) {
        this.pathHelper = this.injector.get(PathHelperService);
      }

      if (!this.apiV3Service) {
        this.apiV3Service = this.injector.get(ApiV3Service);
      }

      super.$initialize(source);

      const attachments = this.attachments || { $source: {}, elements: [] };
      this.attachments = new AttachmentCollectionResource(
        this.injector,
        attachments,
        false,
        this.halInitializer,
        'HalResource',
      );
    }
  };
}
