#!/usr/bin/env python3
"""Compatibility wrapper for moved utils/create_port_mappings.py

Keeps the original `scripts/create_port_mappings.py` entrypoint working by
delegating to the implementation in `utils/`.
"""

from utils.create_port_mappings import main


if __name__ == '__main__':
    main()
        sys.exit(1)
    except Exception as e:
        print(f'ERROR: PATCH {webhook_url} failed: {e}')
        sys.exit(1)


if __name__ == '__main__':
    main()
