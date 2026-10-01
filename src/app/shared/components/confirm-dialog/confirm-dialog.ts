import { Component, effect, input, output } from '@angular/core';
import Swal from 'sweetalert2/dist/sweetalert2.esm.all.js';

@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  templateUrl: './confirm-dialog.html',
  styleUrl: './confirm-dialog.css',
})
export class ConfirmDialogComponent {
  title = input('Are you sure?');
  message = input('');
  confirmLabel = input('Confirm');
  cancelLabel = input('Cancel');
  danger = input(false);
  open = input(false);
  confirmed = output<void>();
  cancelled = output<void>();
  private presenting = false;

  constructor() {
    effect(() => {
      if (this.open() && !this.presenting) {
        void this.present();
      }
    });
  }

  private async present(): Promise<void> {
    this.presenting = true;
    const result = await Swal.fire({
      position: 'center-end',
      icon: this.danger() ? 'warning' : 'question',
      title: this.title(),
      text: this.message(),
      showCancelButton: true,
      confirmButtonText: this.confirmLabel(),
      cancelButtonText: this.cancelLabel(),
      focusCancel: this.danger(),
      reverseButtons: true,
      buttonsStyling: false,
      heightAuto: false,
      customClass: {
        container: 'merchant-swal-container merchant-swal-container--side',
        popup: 'merchant-swal merchant-swal--confirm',
        title: 'merchant-swal__title merchant-swal__title--confirm',
        htmlContainer: 'merchant-swal__message',
        actions: 'merchant-swal__actions',
        confirmButton: this.danger()
          ? 'merchant-swal__button merchant-swal__button--danger'
          : 'merchant-swal__button merchant-swal__button--primary',
        cancelButton: 'merchant-swal__button merchant-swal__button--secondary',
      },
    });

    this.presenting = false;
    if (result.isConfirmed) {
      this.confirmed.emit();
    } else {
      this.cancelled.emit();
    }
  }
}
