# GE_Sky — Global E-Commerce Sky Platform

## نظرة عامة
منصة SaaS متكاملة ومدعومة بالذكاء الاصطناعي تجمع التجارة الإلكترونية، التسويق الرقمي، CRM، التحليلات، الأتمتة، وعملاء الذكاء الاصطناعي.

## التقنيات المستخدمة

### Frontend
- **Next.js 14+** (App Router, SSR, SSG, ISR)
- **TypeScript** (strict mode)
- **Tailwind CSS v3.4+**
- **Framer Motion** (animations)
- **next-intl** (i18n: ar, fr, en)

### Backend
- **NestJS 10+** (Fastify adapter)
- **TypeScript** (strict mode)
- **Prisma** (ORM)
- **PostgreSQL 16+**
- **Redis 7+**

## البنية
```
ge-sky/
├── apps/
│   ├── web/          # Next.js frontend
│   └── api/          # NestJS backend
├── packages/
│   └── shared/       # Shared types
├── turbo.json
└── docker-compose.yml
```

## التشغيل المحلي

```bash
# تثبيت الحزم
npm install

# تشغيل قاعدة البيانات
docker-compose up -d postgres redis

# تطبيق migrations
npm run db:migrate

# تشغيل المشروع
npm run dev
```

## المتغيرات البيئية

انسخ `.env.example` إلى `.env.local` في كل تطبيق وأضف القيم المطلوبة.

## المراحل
- ✅ Phase 1: Foundation
- 🔄 Phase 2: Core Backend
- ⏳ Phase 3: Core Frontend
- ⏳ Phase 4-12: الوحدات الكاملة
