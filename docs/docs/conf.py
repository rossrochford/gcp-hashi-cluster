import sphinx_typlog_theme


# For configuration docs see: https://www.sphinx-doc.org/en/master/usage/configuration.html

# todo: consider rewriting dos using mdBook: https://github.com/rust-lang/mdBook


# -- Project information -----------------------------------------------------

project = 'gcp-hashi-cluster'
copyright = '2020, Ross R'
author = 'Ross R'

master_doc = 'index'

extensions = [
    # see: https://sphinx-rtd-theme.readthedocs.io/en/latest/
    "sphinx_rtd_theme",
    'sphinx.ext.autosectionlabel'
]
autosectionlabel_prefix_document = True

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_typlog_theme'  #"sphinx_rtd_theme"

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ['docs/docs/_static']


if html_theme == 'sphinx_typlog_theme':
    pygments_style = 'sphinx'

    html_css_files = [
        # these paths are relative to html_static_path, unless absolute
        'css/hide-toc.css'
    ]
    html_theme_options = {
        #'description': 'Consul/Nomad cluster for Google Cloud Platform',
        'github_user': 'rossrochford',
        'github_repo': 'gcp-hashi-cluster',
        #'color': '#E8371A',
        #'meta_html': '<meta name="generator" content="sphinx">',
    }
    html_sidebars = {
        '**': [
            #'logo.html',
            'github.html',
            'globaltoc.html',
            # 'relations.html',
            #'sponsors.html',
            'searchbox.html',
        ]
    }

elif html_theme == 'sphinx_rtd_theme':
    html_theme_options = {
        'canonical_url': '',
        'logo_only': True,  # False
        'display_version': False,
        'prev_next_buttons_location': 'both',  #'bottom',
        'style_external_links': False,
        'style_nav_header_background': 'white',
        # Toc options
        'collapse_navigation': False,
        'sticky_navigation': True,
        'navigation_depth': -1,
        'includehidden': True,
        'titles_only': False
    }
