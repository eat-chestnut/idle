@extends('admin.layouts.app')

@section('content')
    <div class="panel">
        <div class="actions" style="justify-content: space-between; margin-bottom: 18px;">
            <div>
                <div class="hint">当前页模式：{{ $mode === 'config' ? '配置维护' : '正式状态查询' }}</div>
            </div>
            @if($mode === 'config')
                <a class="button" href="{{ route('admin.resources.create', ['resource' => $resource]) }}">新建记录</a>
            @endif
        </div>

        @if($filters !== [])
            <form method="GET" action="{{ route('admin.resources.index', ['resource' => $resource]) }}">
                <div class="grid" style="margin-bottom: 16px;">
                    @foreach($filters as $filter)
                        <div>
                            <label for="filter_{{ $filter['name'] }}">{{ $filter['label'] }}</label>
                            @if(($filter['type'] ?? 'text') === 'select')
                                <select id="filter_{{ $filter['name'] }}" name="{{ $filter['name'] }}">
                                    @foreach($filter['options_resolved'] as $optionValue => $optionLabel)
                                        <option value="{{ $optionValue }}" @selected((string) $filter['value'] === (string) $optionValue)>{{ $optionLabel }}</option>
                                    @endforeach
                                </select>
                            @else
                                <input
                                    id="filter_{{ $filter['name'] }}"
                                    name="{{ $filter['name'] }}"
                                    type="{{ $filter['type'] === 'number' ? 'number' : 'text' }}"
                                    value="{{ $filter['value'] }}"
                                >
                            @endif
                        </div>
                    @endforeach
                </div>
                <div class="actions">
                    <button class="button secondary" type="submit">筛选</button>
                    <a class="button ghost" href="{{ route('admin.resources.index', ['resource' => $resource]) }}">重置</a>
                </div>
            </form>
        @endif
    </div>

    <div class="panel">
        <table>
            <thead>
                <tr>
                    @foreach($columns as $column)
                        <th>{{ $column }}</th>
                    @endforeach
                    @if($mode === 'config')
                        <th class="table-actions">操作</th>
                    @endif
                </tr>
            </thead>
            <tbody>
                @forelse($rows as $row)
                    <tr>
                        @foreach($row['cells'] as $cell)
                            <td>{{ $cell }}</td>
                        @endforeach
                        @if($mode === 'config')
                            <td class="table-actions">
                                <a class="button secondary" href="{{ $row['edit_url'] }}">编辑</a>
                            </td>
                        @endif
                    </tr>
                @empty
                    <tr>
                        <td colspan="{{ count($columns) + ($mode === 'config' ? 1 : 0) }}">当前没有符合条件的数据。</td>
                    </tr>
                @endforelse
            </tbody>
        </table>

        <div class="pagination">
            {{ $paginator->links() }}
        </div>
    </div>
@endsection
