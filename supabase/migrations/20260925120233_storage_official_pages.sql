-- ============================================================
-- Photo and maker's page for all 28 Storage products (3201-3228).
-- Every page was opened on 25 Sep 2026 and its title checked (MSI,
-- Kingston, Seagate and WD only render in a real browser; curl gets
-- 403/429 or an empty shell).
--
-- Notes:
--   * Hiksemi and Addlink keep one page per model, not per capacity.
--   * Samsung's semiconductor.samsung.com pages now bounce to a monitors
--     listing, so the Samsung US store pages are used instead.
--   * Seagate redirects to its ASEAN (/as/en/) pages; the canonical link
--     is kept so visitors land on their own region.
--   * Photos are the maker's model shot; a few show a different capacity
--     on the label (P210, Addlink S70/S93, Spatium M450).
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (3201, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-s.html'),
  (3202, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-s.html'),
  (3203, 'https://www.teamgroupinc.com/en/product-detail/ssd/T-FORCE/vulcan-z/vulcan-z-T253TZ512G0C101/'),
  (3204, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-s.html'),
  (3205, 'https://www.patriotmemory.com/products/p210-sata-iii-2-5-ssd'),
  (3206, 'https://www.samsung.com/us/memory-storage/sata-ssd/870-evo-sata-2-5-ssd-500gb-sku-mz-77e500b-am/'),
  (3207, 'https://www.samsung.com/us/memory-storage/sata-ssd/870-evo-sata-2-5-ssd-1tb-sku-mz-77e1t0b-am/'),
  (3208, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-p.html'),
  (3209, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-p.html'),
  (3210, 'https://www.lexar.com/global/products/Lexar-NM610PRO-M-2-2280-PCIe-Gen3x4-NVMe-SSD/'),
  (3211, 'https://www.msi.com/Storage/SPATIUM-M450-PCIe-4.0-NVMe-M.2'),
  (3212, 'https://www.hiksemitech.com/en/hiksemi/all-products/solid-state-drive/consumer-ssd/hs-ssd-wave-p.html'),
  (3213, 'https://www.lexar.com/global/products/Lexar-NM610PRO-M-2-2280-PCIe-Gen3x4-NVMe-SSD/'),
  (3214, 'https://www.addlink.com.tw/pcie-s70'),
  (3215, 'https://www.msi.com/Storage/SPATIUM-M450-PCIe-4.0-NVMe-M.2'),
  (3216, 'https://www.lexar.com/global/products/Lexar-NM790-M-2-2280-PCIe-Gen-4x4-NVMe-SSD/'),
  (3217, 'https://www.msi.com/Storage/SPATIUM-M470-PRO-PCIe-4.0-NVMe-M.2'),
  (3218, 'https://www.msi.com/Storage/SPATIUM-M450-PCIe-4.0-NVMe-M.2'),
  (3219, 'https://www.addlink.com.tw/pcie-s93'),
  (3220, 'https://www.msi.com/Storage/SPATIUM-M571-DLP-PCIe-5.0-NVMe-M.2'),
  (3221, 'https://www.samsung.com/us/memory-storage/nvme-ssd/990-evo-2tb-nvme-ssd-sku-mz-v9e2t0b-am/'),
  (3222, 'https://www.kingston.com/en/ssd/gaming/kingston-fury-renegade-nvme-m2-ssd'),
  (3223, 'https://www.seagate.com/products/hard-drives/barracuda-hard-drive/'),
  (3224, 'https://www.westerndigital.com/products/internal-drives/wd-purple-sata-hdd?sku=WD23PURZ'),
  (3225, 'https://www.seagate.com/products/video-analytics/skyhawk-hard-drive/'),
  (3226, 'https://www.westerndigital.com/products/internal-drives/wd-purple-sata-hdd?sku=WD33PURZ'),
  (3227, 'https://www.seagate.com/products/hard-drives/barracuda-hard-drive/'),
  (3228, 'https://www.westerndigital.com/products/internal-drives/wd-purple-sata-hdd?sku=WD43PURZ')
) AS v(product_id, url)
WHERE p.product_id = v.product_id;
