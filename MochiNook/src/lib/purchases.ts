import Constants from 'expo-constants';
import { Platform } from 'react-native';
import Purchases, {
  LOG_LEVEL,
  PRODUCT_CATEGORY,
  PURCHASES_ERROR_CODE,
  type CustomerInfo,
  type PurchasesError,
  type PurchasesStoreProduct,
} from 'react-native-purchases';

/**
 * RevenueCat wrapper with a safe mock mode.
 *
 * Real mode: set `expo.extra.revenueCat.appleApiKey` / `googleApiKey` in app.json.
 * Mock mode: when the key for this platform is empty, every purchase is simulated
 * locally (nothing is charged) so the whole app can be tested before store setup.
 *
 * MochiNook Plus: $6.99/month or $34.99/year (save 58%), each with a 7-day free trial
 * configured as a free-trial offer on the store products. No lifetime tier.
 */

export type TipSize = 'small' | 'medium' | 'large';
export type PlusPlan = 'monthly' | 'annual';

interface RevenueCatConfig {
  appleApiKey: string;
  googleApiKey: string;
  entitlementId: string;
  plusMonthlyId: string;
  plusAnnualId: string;
  tipProductIds: Record<TipSize, string>;
}

const FALLBACK: RevenueCatConfig = {
  appleApiKey: '',
  googleApiKey: '',
  entitlementId: 'pro',
  plusMonthlyId: 'mochinook_plus_monthly',
  plusAnnualId: 'mochinook_plus_annual',
  tipProductIds: { small: 'mochinook_tip_small', medium: 'mochinook_tip_medium', large: 'mochinook_tip_large' },
};

function readConfig(): RevenueCatConfig {
  const extra = (Constants.expoConfig?.extra ?? {}) as { revenueCat?: Partial<RevenueCatConfig> };
  const rc = extra.revenueCat ?? {};
  return {
    ...FALLBACK,
    ...rc,
    tipProductIds: { ...FALLBACK.tipProductIds, ...(rc.tipProductIds ?? {}) },
  };
}

const config = readConfig();

export const DISPLAY_PRICES = {
  monthly: '$6.99',
  annual: '$34.99',
  tips: { small: '$2.99', medium: '$4.99', large: '$9.99' } as Record<TipSize, string>,
};

function apiKey(): string {
  return Platform.OS === 'ios' ? config.appleApiKey : Platform.OS === 'android' ? config.googleApiKey : '';
}

export const isMockStore = apiKey().trim().length === 0;

/**
 * Test tools (the 5-tap Free/Pro switch and free test purchases) exist ONLY in
 * development or in builds without store keys. A production build with real
 * RevenueCat keys can never unlock Pro without a real purchase.
 */
export const TEST_TOOLS_ALLOWED = __DEV__ || isMockStore;

let configured = false;

export async function initPurchases(onChange: (isPro: boolean) => void): Promise<() => void> {
  if (isMockStore) return () => undefined;
  if (!configured) {
    if (__DEV__) await Purchases.setLogLevel(LOG_LEVEL.WARN);
    Purchases.configure({ apiKey: apiKey() });
    configured = true;
  }
  const listener = (info: CustomerInfo) => onChange(hasPro(info));
  Purchases.addCustomerInfoUpdateListener(listener);
  try {
    onChange(hasPro(await Purchases.getCustomerInfo()));
  } catch {
    // Offline: keep whatever we knew; RevenueCat caches entitlement state on device.
  }
  return () => {
    Purchases.removeCustomerInfoUpdateListener(listener);
  };
}

function hasPro(info: CustomerInfo): boolean {
  return info.entitlements.active[config.entitlementId] !== undefined;
}

export type PurchaseOutcome = { status: 'success' } | { status: 'cancelled' } | { status: 'error'; message: string };

function toOutcome(e: unknown): PurchaseOutcome {
  const err = e as Partial<PurchasesError>;
  if (err.code === PURCHASES_ERROR_CODE.PURCHASE_CANCELLED_ERROR) return { status: 'cancelled' };
  return { status: 'error', message: err.message ?? 'The store had a hiccup. Nothing was charged.' };
}

async function findProduct(id: string, category: PRODUCT_CATEGORY): Promise<PurchasesStoreProduct | null> {
  const products = await Purchases.getProducts([id], category);
  return products.find((p) => p.identifier === id || p.identifier.startsWith(`${id}:`)) ?? products[0] ?? null;
}

export interface PlusOffer {
  monthly: string;
  annual: string;
  /** True when the store reports a free trial on the plan (Google Play free phase / App Store intro offer). */
  trial: { monthly: boolean; annual: boolean };
}

const MOCK_OFFER: PlusOffer = { monthly: DISPLAY_PRICES.monthly, annual: DISPLAY_PRICES.annual, trial: { monthly: true, annual: true } };

function hasTrial(product: PurchasesStoreProduct | undefined): boolean {
  if (!product) return false;
  if (product.defaultOption?.freePhase) return true;
  return product.introPrice?.price === 0;
}

export async function getPlusOffer(): Promise<PlusOffer> {
  if (isMockStore) return MOCK_OFFER;
  try {
    const current = (await Purchases.getOfferings()).current;
    const m = current?.monthly?.product;
    const a = current?.annual?.product;
    return {
      monthly: m?.priceString ?? DISPLAY_PRICES.monthly,
      annual: a?.priceString ?? DISPLAY_PRICES.annual,
      trial: { monthly: hasTrial(m), annual: hasTrial(a) },
    };
  } catch {
    return { ...MOCK_OFFER, trial: { monthly: false, annual: false } };
  }
}

export async function getTipPrices(): Promise<Record<TipSize, string>> {
  if (isMockStore) return { ...DISPLAY_PRICES.tips };
  try {
    const ids = Object.values(config.tipProductIds);
    const products = await Purchases.getProducts(ids, PRODUCT_CATEGORY.NON_SUBSCRIPTION);
    const out = { ...DISPLAY_PRICES.tips };
    for (const size of Object.keys(config.tipProductIds) as TipSize[]) {
      const p = products.find((x) => x.identifier === config.tipProductIds[size]);
      if (p) out[size] = p.priceString;
    }
    return out;
  } catch {
    return { ...DISPLAY_PRICES.tips };
  }
}

/** Buys MochiNook Plus (monthly or annual). In mock mode resolves to success without charging anything. */
export async function purchasePlus(plan: PlusPlan): Promise<PurchaseOutcome> {
  if (isMockStore) return { status: 'success' };
  try {
    const current = (await Purchases.getOfferings()).current;
    const pkg = plan === 'annual' ? current?.annual : current?.monthly;
    if (pkg) {
      await Purchases.purchasePackage(pkg);
      return { status: 'success' };
    }
    const id = plan === 'annual' ? config.plusAnnualId : config.plusMonthlyId;
    const product = await findProduct(id, PRODUCT_CATEGORY.SUBSCRIPTION);
    if (!product) return { status: 'error', message: "Plus isn't available in the store yet. Nothing was charged." };
    await Purchases.purchaseStoreProduct(product);
    return { status: 'success' };
  } catch (e) {
    return toOutcome(e);
  }
}

/** One-time consumable tip. Configure each tip as a consumable product in the stores. */
export async function purchaseTip(size: TipSize): Promise<PurchaseOutcome> {
  if (isMockStore) return { status: 'success' };
  try {
    const product = await findProduct(config.tipProductIds[size], PRODUCT_CATEGORY.NON_SUBSCRIPTION);
    if (!product) return { status: 'error', message: "Tips aren't set up in the store yet. Nothing was charged." };
    await Purchases.purchaseStoreProduct(product);
    return { status: 'success' };
  } catch (e) {
    return toOutcome(e);
  }
}

export async function restorePurchases(): Promise<{ isPro: boolean } | { error: string }> {
  if (isMockStore) return { error: 'Store testing mode is on, so there is nothing to restore yet.' };
  try {
    return { isPro: hasPro(await Purchases.restorePurchases()) };
  } catch (e) {
    return { error: (e as Partial<PurchasesError>).message ?? 'Restore did not work this time. Want to try again later?' };
  }
}
