import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AppKeyGuard, JwtAuthGuard, RolesGuard, ServiceAuthGuard } from './guards';
import { TokenService } from './token.service';

@Global()
@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        global: true,
      }),
    }),
  ],
  providers: [TokenService, JwtAuthGuard, RolesGuard, AppKeyGuard, ServiceAuthGuard],
  exports: [TokenService, JwtAuthGuard, RolesGuard, AppKeyGuard, ServiceAuthGuard],
})
export class AuthModule {}

export * from './jwt-payload';
export * from './token.service';
export * from './guards';