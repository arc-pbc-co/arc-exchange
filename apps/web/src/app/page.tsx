import { ConnectButton } from '@/components/connect-button';

export default function Home() {
  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white/80 backdrop-blur-sm">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center gap-2">
            <span className="text-2xl font-bold text-arc-purple">ARC</span>
            <span className="text-lg font-medium text-gray-600">Exchange</span>
          </div>
          <nav className="hidden items-center gap-8 md:flex">
            <a href="/marketplace" className="text-gray-600 hover:text-arc-purple">
              Marketplace
            </a>
            <a href="/portfolio" className="text-gray-600 hover:text-arc-purple">
              Portfolio
            </a>
          </nav>
          <ConnectButton />
        </div>
      </header>

      {/* Hero Section */}
      <section className="mx-auto max-w-7xl px-4 py-24 sm:px-6 lg:px-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
            Invest in <span className="text-arc-purple">Impact</span>
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-gray-600">
            Access tokenized impact investments on Polygon. Invest in real-world projects that
            generate both financial returns and positive social impact.
          </p>
          <div className="mt-10 flex items-center justify-center gap-x-6">
            <a
              href="/marketplace"
              className="rounded-lg bg-arc-purple px-6 py-3 text-sm font-semibold text-white shadow-sm hover:bg-arc-purple-dark focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-arc-purple"
            >
              Browse Investments
            </a>
            <a href="/about" className="text-sm font-semibold leading-6 text-gray-900">
              Learn more <span aria-hidden="true">→</span>
            </a>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="bg-gray-50 py-24">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="grid gap-8 md:grid-cols-3">
            <div className="rounded-xl bg-white p-8 shadow-sm">
              <div className="mb-4 inline-flex rounded-lg bg-arc-purple/10 p-3">
                <svg
                  className="h-6 w-6 text-arc-purple"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Secure & Compliant</h3>
              <p className="mt-2 text-gray-600">
                KYC/AML verified investors only. Built for US accredited investors with full
                regulatory compliance.
              </p>
            </div>

            <div className="rounded-xl bg-white p-8 shadow-sm">
              <div className="mb-4 inline-flex rounded-lg bg-arc-purple/10 p-3">
                <svg
                  className="h-6 w-6 text-arc-purple"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Fast & Low Cost</h3>
              <p className="mt-2 text-gray-600">
                Built on Polygon for near-instant transactions and minimal gas fees. Trade 24/7
                without intermediaries.
              </p>
            </div>

            <div className="rounded-xl bg-white p-8 shadow-sm">
              <div className="mb-4 inline-flex rounded-lg bg-arc-purple/10 p-3">
                <svg
                  className="h-6 w-6 text-arc-purple"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Real Yields</h3>
              <p className="mt-2 text-gray-600">
                Earn dividends and coupons from real-world projects. Transparent cash flow
                distribution via smart contracts.
              </p>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
