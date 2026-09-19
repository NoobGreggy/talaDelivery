import { Component, input, output } from '@angular/core';

@Component({
  selector: 'app-modal',
  standalone: true,
  templateUrl: './modal.html',
  styleUrl: './modal.css',
})
export class ModalComponent {
  title = input('');
  open = input(false);
  closed = output<void>();

  close(): void {
    this.closed.emit();
  }
}