# One widget, one selected AI provider

[Tiếng Việt](#tiếng-việt)

Enable the optional widget with `./setup.sh install --yes --with-ai-usage` and your other selected options. `--with-codex` remains a compatibility alias. The runtime adds the checksum-pinned **CodexBar CLI 0.83.0**, its resource bundle and notices, approximately 173 MiB; it does not build Swift or install another desktop.

Hover over the sidebar usage indicator to open **AI Usage**. Click the provider name, search the list, then choose a provider. Exactly one selected provider appears in the sidebar and is fetched by the background service. The logo stays inside a padded, fixed-size sidebar box. The popup uses one compact, fixed height for both hover entry paths, refreshes and selector filtering. Longer content scrolls inside it. Selection is remembered across sessions in `~/.config/caelestia/ai-usage.json`. The widget does not combine quotas or automatically rotate providers.

The selector is curated to 13 providers: Codex, OpenAI API, Claude, Antigravity, GitHub Copilot, OpenCode, z.ai / GLM, Kimi Code, Kilo, DeepSeek, Cursor, Gemini and Grok. Provider logos are bundled locally, so opening the widget makes no image requests. Inclusion does not guarantee that every source works on Linux or with your account. Each provider needs its own supported credentials and usage endpoint. Codex subscription limits and OpenAI API billing are separate entries. Missing authentication, unsupported sources and network failures show unknown/unavailable rather than 0% usage.

## Connect a provider

- **Codex:** sign in through your existing Codex CLI. The widget uses only the read-only `account/rateLimits/read` method; it does not send a prompt.
- **Claude, Gemini and other CLI accounts:** sign in with the provider's own tool when supported. The backend explicitly selects the corresponding OAuth/API/web source, so it does not fall back to an interactive chat probe.
- **API keys or manual browser sessions:** configure the selected provider through CodexBar on your own machine. See its [provider setup guides](https://github.com/steipete/CodexBar/blob/v0.83.0/docs/providers.md) and [CLI configuration](https://github.com/steipete/CodexBar/blob/v0.83.0/docs/cli-configuration.md). Do not paste secrets into chat, shell arguments, issues or this repository.

Native YapCap accounts are not automatically imported or synchronized. The widget does not copy YapCap credential stores or browser profiles. Browser-cookie auto-import is not assumed to work on Linux. Some CLI-only providers and inference-probe endpoints are deliberately unavailable in this read-only widget, even when their names appear in the catalog.

Use the refresh button after connecting an account. Provider quotas normally update every minute, with backoff on failures. Only numeric quota windows, balances, static display labels and timestamps enter the widget cache. Raw provider errors, account identity and credentials are omitted. Changing providers clears old windows immediately; an older in-flight request cannot overwrite the new selection.

## Inspect without exposing credentials

```bash
systemctl --user status caelestia-codex-usage.service --no-pager
python3 "$HOME/.local/share/caelestia-pop-os/ai-usage/ai_usage.py" --list
python3 "$HOME/.local/share/caelestia-pop-os/ai-usage/ai_usage.py" --select codex
python3 "$HOME/.local/share/caelestia-pop-os/ai-usage/ai_usage.py" --refresh
```

The systemd filename stays `caelestia-codex-usage.service` for compatibility with existing session dependencies; it now runs the generic backend. The sanitized display cache is `~/.cache/caelestia/ai-usage.json`. XDG directory overrides are respected.

Source is in `src/ai-usage/`, `shell/services/AIUsage.qml`, and the AI Usage bar/popout components. Codex's existing RPC client remains under `src/codex-usage/`. Run `python3 -m unittest discover -s src/ai-usage -v` for the provider-switching, normalization, error, privacy and child-process isolation checks. Real account access still depends on your provider and login state.

## Tiếng Việt

Cài tùy chọn bằng `--with-ai-usage`; cờ cũ `--with-codex` vẫn dùng được. Backend CodexBar CLI cùng resource chiếm khoảng 173 MiB.

1. **Rê chuột vào widget** trên thanh bên để mở AI Usage.
2. **Bấm tên nhà cung cấp**, nhập tên vào ô tìm kiếm rồi chọn.
3. Thanh bên chỉ hiện **một nhà cung cấp bạn chọn**. Lựa chọn được lưu cho lần đăng nhập sau.
4. Sau khi đăng nhập/cấu hình tài khoản tương ứng trên máy, bấm Refresh để đọc lại usage.

Danh sách rút gọn gồm 13 nhà cung cấp phổ biến, có cả Kimi và Kilo. Logo được lưu sẵn trên máy, không cần tải mỗi lần mở widget. Khả năng đọc usage còn phụ thuộc API, kiểu tài khoản và nguồn đăng nhập hỗ trợ trên Linux. Không có dữ liệu sẽ hiện Unknown/Unavailable, không giả thành 0%. Các quota và số dư của những dịch vụ khác nhau không được cộng chung.

Codex dùng đăng nhập CLI hiện có và RPC chỉ đọc. Provider khác dùng nguồn OAuth/API/web phù hợp; API key hoặc cookie cần được cấu hình cục bộ theo [hướng dẫn CodexBar](https://github.com/steipete/CodexBar/blob/v0.83.0/docs/providers.md). Widget không tự chép tài khoản từ YapCap và không nhận mật khẩu/token qua cuộc chat này. Nguồn chỉ hỗ trợ probe bằng yêu cầu suy luận hoặc chưa hỗ trợ trên Linux sẽ báo chưa dùng được.

Tên service cũ được giữ để tương thích, còn giao diện và backend đã dùng chung. Cấu hình chọn provider nằm ở `~/.config/caelestia/ai-usage.json`; cache hiển thị đã lọc dữ liệu ở `~/.cache/caelestia/ai-usage.json`.
