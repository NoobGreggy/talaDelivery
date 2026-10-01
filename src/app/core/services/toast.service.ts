import { Injectable } from '@angular/core';
import type { SweetAlertIcon } from 'sweetalert2';
import Swal from 'sweetalert2/dist/sweetalert2.esm.all.js';

export interface Toast {
  id: number;
  message: string;
  type: 'success' | 'error' | 'info';
}

@Injectable({ providedIn: 'root' })
export class ToastService {
  show(message: string, type: Toast['type'] = 'success'): void {
    // Let Angular remove any form side panel before SweetAlert mounts its
    // document-level response overlay.
    queueMicrotask(() => {
      void Swal.fire({
        target: document.body,
        toast: true,
        position: 'bottom-end',
        icon: type as SweetAlertIcon,
        title: message,
        timer: 4500,
        timerProgressBar: true,
        showConfirmButton: false,
        showCloseButton: true,
        heightAuto: false,
        customClass: {
          container: 'merchant-swal-container',
          popup: 'merchant-swal merchant-swal--toast',
          title: 'merchant-swal__title',
          timerProgressBar: 'merchant-swal__progress',
          closeButton: 'merchant-swal__close',
        },
      });
    });
  }
}
