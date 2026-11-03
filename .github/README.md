# dotfiles

Cấu hình cá nhân cho shell (zsh, bash), tmux, Neovim (LazyVim), Claude Code và opencode.

Repo được quản lý theo kiểu bare repo: dữ liệu git nằm ở thư mục ~/dotfiles, còn work tree chính là thư mục home. Các file được track nằm đúng vị trí thật của chúng (~/.zshrc, ~/.config/nvim, ~/.claude, ...), không cần symlink.

## Các nhánh

| Nhánh  | Dùng cho                         |
|--------|----------------------------------|
| mac    | macOS                            |
| linux  | Linux                            |
| master | Bản cũ, không còn dùng hằng ngày |

Workflow GitHub Actions trong thư mục .github/workflows tự cherry-pick mỗi commit push lên mac sang linux và ngược lại. Commit được cherry-pick sẽ có tiền tố [cherry-picked]. Muốn một commit chỉ nằm ở một nhánh thì ghi dòng sau vào phần body của commit message:

```
[do not auto cherry-pick]
```

## Cài đặt trên máy mới

### 1. Chuẩn bị

- git, zsh (hoặc bash)
- SSH key đã add vào GitHub (repo clone qua SSH)
- macOS: Homebrew

### 2. Clone bare repo

```bash
git clone --bare git@github.com:luytbq/dotfiles.git "$HOME/dotfiles"
```

### 3. Tạo lệnh dotfiles

Lệnh dotfiles là git trỏ git-dir vào ~/dotfiles và work tree vào home. Cách 1, dùng script (giống máy hiện tại):

```bash
sudo tee /usr/local/bin/dotfiles >/dev/null <<'EOF'
#!/bin/bash
/usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME" "$@"
EOF
sudo chmod +x /usr/local/bin/dotfiles
```

Cách 2, không cần sudo, dùng alias tạm cho phiên hiện tại:

```bash
alias dotfiles='/usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME"'
```

### 4. Ẩn file untracked

Home có rất nhiều file không thuộc repo, tắt hiển thị để dotfiles status gọn:

```bash
dotfiles config --local status.showUntrackedFiles no
```

### 5. Checkout đúng nhánh

Bare clone không tự tạo remote-tracking branch, cần cấu hình fetch rồi checkout:

```bash
dotfiles config --local remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
dotfiles fetch origin
dotfiles checkout mac      # hoặc: dotfiles checkout linux
```

Nếu checkout báo lỗi vì file đã tồn tại (ví dụ ~/.zshrc mặc định), chuyển các file đó sang thư mục backup rồi checkout lại:

```bash
mkdir -p "$HOME/.dotfiles-backup"
dotfiles checkout mac 2>&1 | grep -E '^[[:space:]]+' | awk '{print $1}' | while read -r f; do
  mkdir -p "$HOME/.dotfiles-backup/$(dirname "$f")"
  mv "$HOME/$f" "$HOME/.dotfiles-backup/$f"
done
dotfiles checkout mac
```

Cuối cùng gắn upstream để pull/push không cần chỉ nhánh:

```bash
dotfiles branch --set-upstream-to=origin/mac mac
```

### 6. Cài các công cụ đi kèm

Repo chỉ chứa cấu hình, các công cụ dưới đây cần cài riêng.

tmux plugin manager (tpm), sau đó mở tmux và bấm prefix + I để cài plugin:

```bash
git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
```

Neovim: cài Neovim bản mới, mở nvim lần đầu thì LazyVim tự cài plugin theo lazy-lock.json.

Công cụ shell được .zshrc dùng tới (cài nếu cần): fzf, openjdk@17 (đường dẫn JAVA_HOME trong .zshrc trỏ vào bản Homebrew).

Claude Code: cài Claude Code rồi chạy script cài bộ plugin dùng chung. File ~/.claude/settings.json không được track vì mỗi máy một cấu hình riêng.

```bash
bash "$HOME/.claude/scripts/install-plugins.sh"
```

opencode và acpx: xem hướng dẫn trong ~/.claude/skills/acpx/harnesses.md.

### 7. Nạp lại shell

```bash
exec zsh
```

## Dùng hằng ngày

```bash
dotfiles status
dotfiles add ~/.zshrc
dotfiles commit -m "feat zsh: ..."
dotfiles push
dotfiles pull
```

Chỉ track file mới bằng cách add đích danh đường dẫn. Đừng chạy dotfiles add với dấu chấm hoặc -A vì work tree là cả thư mục home.
