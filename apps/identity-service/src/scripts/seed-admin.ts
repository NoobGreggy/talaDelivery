import 'dotenv/config';
import { AppDataSource } from '../config/data-source';
import { User } from '../entities/user.entity';
import { Role, UserStatus } from '@taladelivery/contracts';
import * as bcrypt from 'bcryptjs';

async function seedAdmin(): Promise<void> {
  await AppDataSource.initialize();
  const users = AppDataSource.getRepository(User);

  const email = process.env.SEED_ADMIN_EMAIL ?? 'admin@taladelivery.com';
  const password = process.env.SEED_ADMIN_PASSWORD ?? 'Admin@123456';
  const name = process.env.SEED_ADMIN_NAME ?? 'Platform Admin';

  const existing = await users.findOne({ where: { email } });
  if (existing) {
    console.log(`Admin user already exists: ${email} (id: ${existing.id}, role: ${existing.role})`);
    await AppDataSource.destroy();
    return;
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  const admin = await users.save(
    users.create({
      name,
      email,
      phone: null,
      password: hashedPassword,
      role: Role.PlatformAdmin,
      status: UserStatus.Active,
    }),
  );

  console.log(`Admin user created successfully:`);
  console.log(`  ID:    ${admin.id}`);
  console.log(`  Name:  ${admin.name}`);
  console.log(`  Email: ${admin.email}`);
  console.log(`  Role:  ${admin.role}`);
  console.log(`  Pass:  ${password}`);

  await AppDataSource.destroy();
}

seedAdmin().catch((error) => {
  console.error('Failed to seed admin:', error);
  process.exit(1);
});
