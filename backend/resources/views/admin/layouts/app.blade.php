<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? '后台管理' }}</title>
    <style>
        :root {
            --bg: #f4efe6;
            --panel: #fffdf9;
            --border: #dbcdb6;
            --text: #2d2518;
            --muted: #7a6a54;
            --accent: #8a4f1d;
            --accent-soft: #f4dfc1;
            --danger: #a03d2f;
            --success: #2d6b4b;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: "PingFang SC", "Noto Serif SC", "Hiragino Sans GB", sans-serif;
            color: var(--text);
            background:
                radial-gradient(circle at top left, rgba(242, 197, 131, 0.35), transparent 28%),
                linear-gradient(180deg, #f8f1e5 0%, #efe5d7 100%);
            min-height: 100vh;
        }
        a { color: inherit; text-decoration: none; }
        .admin-shell {
            display: grid;
            grid-template-columns: 280px 1fr;
            min-height: 100vh;
        }
        .admin-sidebar {
            padding: 28px 22px;
            border-right: 1px solid rgba(103, 74, 41, 0.12);
            background: rgba(255, 252, 246, 0.88);
            backdrop-filter: blur(8px);
        }
        .brand {
            margin-bottom: 24px;
            padding-bottom: 18px;
            border-bottom: 1px solid var(--border);
        }
        .brand h1 {
            margin: 0 0 8px;
            font-size: 24px;
            letter-spacing: 1px;
        }
        .brand p {
            margin: 0;
            color: var(--muted);
            font-size: 13px;
        }
        .nav-group {
            margin-bottom: 24px;
        }
        .nav-group h2 {
            margin: 0 0 12px;
            font-size: 13px;
            color: var(--muted);
            letter-spacing: 1px;
        }
        .nav-link {
            display: block;
            padding: 10px 12px;
            border-radius: 10px;
            margin-bottom: 6px;
            font-size: 14px;
        }
        .nav-link.active {
            background: var(--accent);
            color: #fff9f0;
            box-shadow: 0 10px 20px rgba(138, 79, 29, 0.16);
        }
        .nav-link:hover {
            background: rgba(138, 79, 29, 0.08);
        }
        .admin-main {
            padding: 28px 32px 40px;
        }
        .topbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 22px;
        }
        .topbar h1 {
            margin: 0;
            font-size: 28px;
        }
        .topbar p {
            margin: 8px 0 0;
            color: var(--muted);
            font-size: 13px;
        }
        .panel {
            background: var(--panel);
            border: 1px solid rgba(103, 74, 41, 0.12);
            border-radius: 16px;
            box-shadow: 0 18px 40px rgba(103, 74, 41, 0.08);
            padding: 22px;
            margin-bottom: 18px;
        }
        .actions {
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }
        .button {
            appearance: none;
            border: 0;
            border-radius: 10px;
            background: var(--accent);
            color: #fff8ef;
            padding: 10px 16px;
            font-size: 14px;
            cursor: pointer;
        }
        .button.secondary {
            background: rgba(138, 79, 29, 0.12);
            color: var(--accent);
        }
        .button.ghost {
            background: transparent;
            border: 1px solid var(--border);
            color: var(--text);
        }
        .button.danger {
            background: var(--danger);
        }
        form.inline {
            display: inline;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 14px;
        }
        label {
            display: block;
            font-size: 13px;
            color: var(--muted);
            margin-bottom: 6px;
        }
        input[type="text"],
        input[type="number"],
        input[type="password"],
        select {
            width: 100%;
            height: 42px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: #fffdfa;
            padding: 0 12px;
            font-size: 14px;
        }
        input[readonly],
        select[disabled] {
            background: #efe7dc;
            color: #786b58;
        }
        .checkbox-wrap {
            display: flex;
            align-items: center;
            gap: 8px;
            padding-top: 30px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        th, td {
            padding: 12px 10px;
            border-bottom: 1px solid rgba(103, 74, 41, 0.1);
            text-align: left;
            vertical-align: top;
        }
        th {
            color: var(--muted);
            font-size: 12px;
            letter-spacing: 0.4px;
        }
        .table-actions {
            white-space: nowrap;
        }
        .flash {
            padding: 12px 14px;
            border-radius: 10px;
            margin-bottom: 16px;
            font-size: 14px;
        }
        .flash.success {
            background: rgba(45, 107, 75, 0.12);
            color: var(--success);
        }
        .flash.error {
            background: rgba(160, 61, 47, 0.12);
            color: var(--danger);
        }
        .hint {
            color: var(--muted);
            font-size: 12px;
        }
        .pagination {
            margin-top: 18px;
        }
        pre {
            margin: 0;
            white-space: pre-wrap;
            word-break: break-word;
            background: #f5ede1;
            border: 1px solid rgba(103, 74, 41, 0.08);
            border-radius: 12px;
            padding: 14px;
            font-size: 13px;
            line-height: 1.6;
        }
        @media (max-width: 960px) {
            .admin-shell { grid-template-columns: 1fr; }
            .admin-sidebar { border-right: 0; border-bottom: 1px solid rgba(103, 74, 41, 0.12); }
        }
    </style>
</head>
<body>
<div class="admin-shell">
    <aside class="admin-sidebar">
        <div class="brand">
            <h1>山海巡厄录后台</h1>
            <p>第一阶段最小配置与查询后台</p>
        </div>
        @foreach($navigation as $section => $items)
            <div class="nav-group">
                <h2>{{ $section }}</h2>
                @foreach($items as $item)
                    <a
                        class="nav-link {{ (($nav_key ?? ($resource ?? '')) === ($item['nav_key'] ?? $item['resource'])) ? 'active' : '' }}"
                        href="{{ $item['url'] }}"
                    >
                        {{ $item['title'] }}
                    </a>
                @endforeach
            </div>
        @endforeach
    </aside>

    <main class="admin-main">
        <div class="topbar">
            <div>
                <h1>{{ $title ?? '' }}</h1>
                <p>当前登录：{{ auth('admin')->user()?->name }}（{{ auth('admin')->user()?->username }}）</p>
            </div>
            <form class="inline" method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit" class="button ghost">退出登录</button>
            </form>
        </div>

        @if(session('status'))
            <div class="flash success">{{ session('status') }}</div>
        @endif

        @if($errors->any())
            <div class="flash error">
                {{ $errors->first() }}
            </div>
        @endif

        @yield('content')
    </main>
</div>
</body>
</html>
