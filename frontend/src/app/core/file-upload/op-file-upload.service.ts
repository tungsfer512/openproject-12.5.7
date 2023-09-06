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

import { Injectable } from '@angular/core';
import {
  HttpClient,
  HttpEvent,
  HttpEventType,
  HttpResponse,
} from '@angular/common/http';
import { Observable } from 'rxjs';
import { filter, map, share } from 'rxjs/operators';
import { HalResourceService } from 'core-app/features/hal/services/hal-resource.service';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';

export interface UploadFile extends File {
  description?:string;
  customName?:string;
}

export interface UploadBlob extends Blob {
  description?:string;
  customName?:string;
  name?:string;
}

export type UploadHttpEvent = HttpEvent<HalResource>;
export type UploadInProgress = [UploadFile, Observable<UploadHttpEvent>];

export interface UploadResult {
  uploads:UploadInProgress[];
  finished:Promise<any[]>;
}

export interface MappedUploadResult {
  uploads:UploadInProgress[];
  finished:Promise<{ response:any, uploadUrl:string }[]>;
}

@Injectable()
export class OpenProjectFileUploadService {
  constructor(
    protected readonly http:HttpClient,
    protected readonly halResource:HalResourceService,
  ) { }

  /**
   * Upload multiple files and return a promise for each uploading file and a single promise for all processed uploads
   * with their accessible URLs returned.
   */
  public uploadAndMapResponse(url:string, files:UploadFile[]):MappedUploadResult {
    const { uploads, finished } = this.upload(url, files);
    const mapped = finished
      .then((result:HalResource[]) => result.map((element:HalResource) => ({
        response: element,
        uploadUrl: (element.staticDownloadLocation as unknown&{ href:string }).href,
      }))) as Promise<{ response:HalResource, uploadUrl:string }[]>;

    return { uploads, finished: mapped } as MappedUploadResult;
  }

  /**
   * Upload multiple files and return a promise for each uploading file and a single promise for all processed uploads
   * Ignore directories.
   */
  public upload(url:string, files:UploadFile[], method = 'post'):UploadResult {
    files = _.filter(files, (file:UploadFile) => file.type !== 'directory');
    const uploads:UploadInProgress[] = _.map(files, (file:UploadFile) => this.uploadSingle(url, file, method));

    const finished = this.whenFinished(uploads);
    return { uploads, finished } as UploadResult;
  }

  /**
   * Upload a single file, get an UploadResult observable
   */
  public uploadSingle(
    url:string,
    file:UploadFile|UploadBlob,
    method = 'post',
    responseType:'json'|'text' = 'json',
  ):UploadInProgress {
    const formData = new FormData();
    const metadata = {
      description: file.description,
      fileName: file.customName || file.name,
    };

    // add the metadata object
    formData.append(
      'metadata',
      JSON.stringify(metadata),
    );

    // Add the file
    formData.append('file', file, metadata.fileName);

    const observable = this.http.request(
      method,
      url,
      {
        body: formData,
        // Observe the response, not the body
        observe: 'events',
        withCredentials: true,
        responseType,
        // Subscribe to progress events. subscribe() will fire multiple times!
        reportProgress: true,
      },
    ).pipe(share());

    return [file, observable] as UploadInProgress;
  }

  /**
   * Create a promise for all uploaded responses when all uploads are fully uploaded.
   *
   * @param {UploadInProgress[]} uploads
   */
  private whenFinished(uploads:UploadInProgress[]):Promise<HalResource[]> {
    const promises = uploads.map(([_, observable]) => observable
      .pipe(
        filter((evt) => evt.type === HttpEventType.Response),
        map((evt:HttpResponse<HalResource>) => this.halResource.createHalResource(evt.body)),
      )
      .toPromise());

    return Promise.all(promises);
  }
}
