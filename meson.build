project('brainlib', 'vala', 'c', meson_version : '>= 1.0.0', version : '1.0',)

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

add_project_arguments(['--pkg', 'yyjson'], language: 'vala')

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('yyjson', static: true)
]

sources = files(
  'Anthropic.vala',
  'BearerCompatible.vala',
  'BrainIa.vala',
  'Default.vala',
  'Gemini.vala',
  'Glm.vala',
  'HttpClient.vala',
  'Mistral.vala',
  'OpenAi.vala',
  'Response.vala',
)

brain_lib = library(
  'brain',
  sources,
  dependencies : dependencies,
  c_args: '-w',
  install : true,
)

brain_dep = declare_dependency(
  link_with : brain_lib,
  dependencies : dependencies,
  include_directories : include_directories('.')
)

executable('brain-test',
  'main.vala',
  dependencies : brain_dep
)

meson.override_dependency('BrainLib', brain_dep)
