## Using Fedora Atomic Desktop

### Important Notice for Users:

If you are using Fedora Atomic Desktop, please follow the instructions below:

**Unverified Registry (Before Switching to Signed Version):**

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/letabouret/up
```
**Signed version :**
 
```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/letabouret/up:latest
```

### Credits

Thank you for the contributions of the users listed below for providing the foundational elements to create this image.
- https://github.com/ublue-os
- https://github.com/noelmiller
- https://github.com/bsherman

Icons by vinceliuice :
https://github.com/vinceliuice/Tela-icon-theme
