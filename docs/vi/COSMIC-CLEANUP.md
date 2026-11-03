# Dọn dung lượng tùy chọn, vẫn giữ COSMIC

[English](../en/COSMIC-CLEANUP.md) · [Bảo trì](MAINTENANCE.md)

Giữ COSMIC là cách khôi phục được hỗ trợ cho bản pre-release này. Cài Hyprland không cần gỡ COSMIC; trình cài không có bước tự gỡ COSMIC. Bỏ hẳn một desktop là việc chuyển đổi riêng, có ảnh hưởng dependency và đường cứu hộ. Hướng dẫn này ưu tiên lấy lại dung lượng mà vẫn giữ phiên dự phòng.

## Đo trước

```bash
df -h "$HOME" /opt /tmp
du -sh "$HOME/.cache/caelestia-pop-os" 2>/dev/null
du -sh "$HOME/.local/share/caelestia-pop-os" 2>/dev/null
du -sh "$HOME/Videos/Recordings" 2>/dev/null
sudo du -sh /var/cache/apt/archives /opt/qt6 /opt/caelestia-wayland
flatpak list --app --columns=application,size
```

Nếu đổi cache/XDG, dùng đường dẫn thực tế. Thiếu thư mục/lệnh `flatpak` có thể chỉ là chưa cài. File build, gói đã tải, video cũ và app không dùng đôi khi chiếm nhiều hơn bản thân phiên dự phòng.

## Dọn trong phạm vi rõ ràng

Trong repo, xem trước rồi chỉ dọn phần build dự án:

```bash
./setup.sh clean-cache --dry-run
./setup.sh clean-cache --yes
```

Thêm đúng `--cache-dir PATH` đã chọn nếu cần. Source/download/receipt và runtime đã cài vẫn giữ. Giữ backup deploy; đó không phải thư mục build bỏ đi.

Có thể xóa cache gói APT đã tải mà không gỡ gói đã cài:

```bash
sudo apt clean
```

Lệnh này không gỡ COSMIC và không thu hồi phần thư viện đang cài. Xem video/ảnh cũ bằng file manager, chỉ xóa thứ không còn cần. Kiểm tra rồi mới dọn Trash. Với app tùy chọn, dùng trình quản lý app COSMIC hoặc chọn đúng từng package/Flatpak để gỡ sau khi xem thông tin. Đừng gỡ một app chỉ vì tên có `cosmic`: desktop này giữ `cosmic-files` và greeter có chủ ý.

## Xem trước mọi lần gỡ gói

Hai lệnh sau chỉ xem thông tin; thay bằng tên một package tùy chọn đã chọn cụ thể trước khi cân nhắc gỡ:

```bash
apt-cache rdepends --installed PACKAGE_NAME
apt-get --simulate remove PACKAGE_NAME
```

Đọc toàn bộ danh sách gỡ. Hủy nếu gồm desktop cứu hộ, greeter, nguồn điện/driver System76, mạng, âm thanh, portal, keyring hoặc thứ bạn còn dùng. Không chạy `sudo apt purge 'cosmic*'`, glob desktop rộng, `autoremove` hàng loạt hay dọn orphan package trong quy trình này. Không gỡ `pop-desktop` chỉ để danh sách package trông gọn.

Giữ `cosmic-greeter`, `system76-power`, gói NVIDIA, PipeWire, NetworkManager, keyring và portal đang hoạt động. Không thay bằng `power-profiles-daemon`. Chừa chỗ cho cập nhật kernel/driver/hệ điều hành; mặc định giữ thêm 8 GiB của trình cài là có chủ ý.

Nếu vẫn thiếu chỗ, chuyển cache build riêng sang ổ lớn hơn, giảm file build giữ lại hoặc mở rộng phân vùng. Đọc [khôi phục](MAINTENANCE.md) trước khi chủ động làm một dự án gỡ COSMIC riêng.
