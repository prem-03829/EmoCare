#models
import argostranslate.package
import argostranslate.translate

argostranslate.package.update_package_index()
available_packages = argostranslate.package.get_available_packages()

# Install Hindi ↔ English
for pkg in available_packages:
    if (pkg.from_code == "hi" and pkg.to_code == "en") or \
       (pkg.from_code == "en" and pkg.to_code == "hi"):
        download_path = pkg.download()
        argostranslate.package.install_from_path(download_path)

# Install Marathi ↔ English (if available)
for pkg in available_packages:
    if (pkg.from_code == "mr" and pkg.to_code == "en") or \
       (pkg.from_code == "en" and pkg.to_code == "mr"):
        download_path = pkg.download()
        argostranslate.package.install_from_path(download_path)