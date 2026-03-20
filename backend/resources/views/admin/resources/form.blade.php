@extends('admin.layouts.app')

@section('content')
    <div class="panel">
        <div class="actions" style="justify-content: space-between; margin-bottom: 18px;">
            <div class="hint">当前资源：{{ $page_title }}</div>
            <a class="button ghost" href="{{ $back_url }}">返回列表</a>
        </div>

        <form method="POST" action="{{ $form_action }}">
            @csrf
            @if($form_method !== 'POST')
                @method($form_method)
            @endif

            <div class="grid">
                @foreach($fields as $field)
                    @if(($field['type'] ?? 'text') === 'checkbox')
                        <div class="checkbox-wrap">
                            <input id="field_{{ $field['name'] }}" name="{{ $field['name'] }}" type="checkbox" value="1" @checked((bool) $field['value'])>
                            <label for="field_{{ $field['name'] }}" style="margin: 0;">{{ $field['label'] }}</label>
                        </div>
                    @elseif(($field['type'] ?? 'text') === 'select')
                        <div>
                            <label for="field_{{ $field['name'] }}">{{ $field['label'] }}</label>
                            <select
                                id="field_{{ $field['name'] }}"
                                name="{{ $field['readonly'] ? '' : $field['name'] }}"
                                @disabled($field['readonly'])
                            >
                                @foreach($field['options_resolved'] as $optionValue => $optionLabel)
                                    <option value="{{ $optionValue }}" @selected((string) $field['value'] === (string) $optionValue)>{{ $optionLabel }}</option>
                                @endforeach
                            </select>
                            @if($field['readonly'])
                                <input type="hidden" name="{{ $field['name'] }}" value="{{ $field['value'] }}">
                            @endif
                        </div>
                    @else
                        <div>
                            <label for="field_{{ $field['name'] }}">{{ $field['label'] }}</label>
                            <input
                                id="field_{{ $field['name'] }}"
                                name="{{ $field['name'] }}"
                                type="{{ ($field['type'] ?? 'text') === 'number' ? 'number' : 'text' }}"
                                value="{{ $field['value'] }}"
                                @if(isset($field['min'])) min="{{ $field['min'] }}" @endif
                                @readonly($field['readonly'])
                            >
                        </div>
                    @endif
                @endforeach
            </div>

            <div class="actions" style="margin-top: 22px;">
                <button class="button" type="submit">提交保存</button>
                <a class="button ghost" href="{{ $back_url }}">取消</a>
            </div>
        </form>
    </div>
@endsection
