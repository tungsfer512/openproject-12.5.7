import { UploadBlob } from 'core-app/core/file-upload/op-file-upload.service';

function dataURItoBlob(dataURI:string) {
  const bytes = dataURI.split(',')[0].indexOf('base64') >= 0
    ? atob(dataURI.split(',')[1])
    : unescape(dataURI.split(',')[1]);
  const mime = dataURI.split(',')[0].split(':')[1].split(';')[0];
  const max = bytes.length;
  const ia = new Uint8Array(max);
  for (let i = 0; i < max; i += 1) {
    ia[i] = bytes.charCodeAt(i);
  }
  return new Blob([ia], { type: mime });
}

/**
 * Resize an image to the given max dimension, returning the data URL and a blob
 * Based on https://stackoverflow.com/a/39235724/420614
 *
 * @param {maxSize} Max width or height
 * @param {HTMLImageElement} Input image
 */
export function resizeImage(maxSize:number, image:HTMLImageElement):[string, UploadBlob] {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d')!;

  let { width } = image;
  let { height } = image;

  if (width > height) {
    if (width > maxSize) {
      height *= maxSize / width;
      width = maxSize;
    }
  } else if (height > maxSize) {
    width *= maxSize / height;
    height = maxSize;
  }

  canvas.width = width;
  canvas.height = height;
  ctx.drawImage(image, 0, 0, width, height);
  const dataUrl = canvas.toDataURL('image/jpeg');
  return [dataUrl, dataURItoBlob(dataUrl)];
}

/**
 * Resize a file input to the given max dimension, returning the data URL and a blob
 *
 * @param {maxSize} Max width or height
 * @param {File} Input file
 */
export function resizeFile(maxSize:number, file:File):Promise<[string, UploadBlob]> {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = (readerEvent:any) => {
      const image = new Image();
      image.onload = () => resolve(resizeImage(maxSize, image));
      image.src = readerEvent.target.result;
    };
    reader.readAsDataURL(file);
  });
}
