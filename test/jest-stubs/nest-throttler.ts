/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable @typescript-eslint/no-unused-vars */
/**
 * Runtime stub for `@nestjs/throttler`. Only `ThrottlerException` is
 * referenced (by the shared exception filter), as a value for instanceof
 * checks the tests never exercise.
 */
import { HttpException } from './nest-common';

export class ThrottlerException extends HttpException {
  constructor(message?: string) {
    super(message ?? 'Throttler Exception', 429);
    this.name = 'ThrottlerException';
  }
}