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

import { getType } from 'mime';
import { Injectable } from '@angular/core';
import { HttpEvent, HttpResponse } from '@angular/common/http';
import { from, Observable, of } from 'rxjs';
import { share, switchMap } from 'rxjs/operators';

import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { EXTERNAL_REQUEST_HEADER } from 'core-app/features/hal/http/openproject-header-interceptor';
import {
  OpenProjectFileUploadService, UploadBlob, UploadFile, UploadInProgress,
} from './op-file-upload.service';

interface PrepareUploadResult {
  url:string;
  form:FormData;
  response:{
    _links:{
      completeUpload:{
        href:string;
      };
    };
  };
}

@Injectable()
export class OpenProjectDirectFileUploadService extends OpenProjectFileUploadService {
  /**
   * Upload a single file, get an UploadResult observable
   */
  public uploadSingle(url:string, file:UploadFile|UploadBlob, method = 'post') {
    const observable = from(this.getDirectUploadFormFrom(url, file))
      .pipe(
        switchMap(this.uploadToExternal(file, method)),
        share(),
      );

    return [file, observable] as UploadInProgress;
  }

  private uploadToExternal(file:UploadFile|UploadBlob, method:string):(result:PrepareUploadResult) => Observable<HttpEvent<unknown>> {
    return (result) => {
      result.form.append('file', file, file.customName || file.name);

      return this.http.request(
        method,
        result.url,
        {
          body: result.form,
          // Observe the response, not the body
          observe: 'events',
          // This is important as the CORS policy for the bucket is * and you can't use credentials then,
          // besides we don't need them here anyway.
          headers: {
            [EXTERNAL_REQUEST_HEADER]: 'true',
          },
          responseType: 'text',
          // Subscribe to progress events. subscribe() will fire multiple times!
          reportProgress: true,
        },
      ).pipe(
        switchMap(this.finishUpload(result)),
      );
    };
  }

  private finishUpload(result:PrepareUploadResult):(result:HttpEvent<unknown>) => Observable<HttpEvent<unknown>> {
    return (event) => {
      if (event instanceof HttpResponse) {
        return this
          .http
          .get(
            result.response?._links?.completeUpload?.href,
            { observe: 'response' },
          );
      }

      // Return as new observable due to switchMap
      return of(event);
    };
  }

  public async getDirectUploadFormFrom(url:string, file:UploadFile|UploadBlob):Promise<PrepareUploadResult> {
    const fileName = file.customName || file.name;
    const contentType = (file.type || (fileName && getType(fileName)) || '' as string);

    const formData = new FormData();
    const metadata = {
      fileName,
      contentType,
      description: file.description,
      fileSize: file.size,
    };

    /*
     * @TODO We could calculate the MD5 hash here too and pass that.
     * The MD5 hash can be used as the `content-md5` option during the upload to S3 for instance.
     * This way S3 can verify the integrity of the file which we currently don't do.
     */

    // add the metadata object
    formData.append(
      'metadata',
      JSON.stringify(metadata),
    );

    const result = await this.http.request<HalResource>(
      'post',
      url,
      {
        body: formData,
        withCredentials: true,
        responseType: 'json',
      },
    ).toPromise();

    const form = new FormData();

    _.each(result._links.addAttachment.form_fields, (value, key) => {
      form.append(key, value);
    });

    return {
      form,
      url: result._links.addAttachment.href,
      response: result as any,
    };
  }
}
