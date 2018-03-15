import sphinx.builders.manpage
import sphinx.writers.manpage
from docutils.frontend import OptionParser
from sphinx.util.console import bold, darkgreen
from six import string_types
from docutils.io import FileOutput
from os import path
from sphinx.util.nodes import inline_all_toctrees
from sphinx import addnodes

"""
    Extension based on sphinx builtin manpage.
    It does not write its own .SH NAME based on config,
    but leaves everything to actual reStructuredText file content.
"""


class ManualPageTranslator(sphinx.writers.manpage.ManualPageTranslator):

    def header(self):
        tmpl = (".TH \"%(title_upper)s\" \"%(manual_section)s\""
                " \"%(date)s\" \"%(version)s\" \"%(manual_group)s\"\n")
        return tmpl % self._docinfo


class ManualPageWriter(sphinx.writers.manpage.ManualPageWriter):

    def __init__(self, builder):
        super().__init__(builder)
        self.translator_class = (
            self.builder.translator_class or ManualPageTranslator)


class ManualPageBuilder(sphinx.builders.manpage.ManualPageBuilder):

    name = 'cman'
    default_translator_class = ManualPageTranslator

    def write(self, *ignored):
        docwriter = ManualPageWriter(self)
        docsettings = OptionParser(
            defaults=self.env.settings,
            components=(docwriter,),
            read_config_files=True).get_default_values()

        self.info(bold('writing... '), nonl=True)

        for info in self.config.man_pages:
            docname, name, description, authors, section = info
            if isinstance(authors, string_types):
                if authors:
                    authors = [authors]
                else:
                    authors = []

            targetname = '%s.%s' % (name, section)
            self.info(darkgreen(targetname) + ' { ', nonl=True)
            destination = FileOutput(
                destination_path=path.join(self.outdir, targetname),
                encoding='utf-8')

            tree = self.env.get_doctree(docname)
            docnames = set()
            largetree = inline_all_toctrees(self, docnames, docname, tree,
                                            darkgreen, [docname])
            self.info('} ', nonl=True)
            self.env.resolve_references(largetree, docname, self)
            # remove pending_xref nodes
            for pendingnode in largetree.traverse(addnodes.pending_xref):
                pendingnode.replace_self(pendingnode.children)

            largetree.settings = docsettings
            largetree.settings.title = name
            largetree.settings.subtitle = description
            largetree.settings.authors = authors
            largetree.settings.section = section

            docwriter.write(largetree, destination)
        self.info()


def setup(app):
    app.add_builder(ManualPageBuilder)
