'use strict';

import m from 'mithril';
import Agenda from './Agenda';

var AgendaComponent = {
    oninit: Agenda.init,
    view: function() {
        if(Agenda.agenda) {
            return m('h2', [
                m('button', { onclick: function() { Agenda.decCurrent(); } }, '|<'),
                m.trust('&sect;'),
                (Agenda.current + 1) + '. ',
                Agenda.getCurrent().title,
                m('button', { onclick: function() { Agenda.incCurrent(); } }, '>|')
            ]);
        }
    }
}

var MeetingAdmin = {
    view: function() {
        return m('div', [
            m('section', [
                m(AgendaComponent)
            ]),
            m('section', [
                m('p', [
                    m('label', [
                        'Number',
                        m('br'),
                        m('input', { type: 'text' })
                    ])
                ]),
                m('p', [
                    m('input', { type: 'submit', value: 'Add to speaker list!' })
                ])
            ]),
            m('section', [
                m('h2', 'First'),
                m('ol', [
                    m('li', [
                        m('button', 'DEL'),
                        'Bob Bobson'
                    ]),
                    m('li', [
                        m('button', 'DEL'),
                        'Eric Ericson'
                    ]),
                    m('li', [
                        m('button', 'DEL'),
                        'Mc Hammer'
                    ]),
                ])
            ]),
            m('section', [
                m('h2', 'Second'),
                m('ol', [
                    m('li', [
                        m('button', 'DEL'),
                        'Woody Woodpecker'
                    ]),
                    m('li', [
                        m('button', 'DEL'),
                        'Doland Dcuk'
                    ]),
                ])
            ]),
            m('section', [
                m('button', 'Push speaker list'),
                m('button', 'Pop speaker list'),
            ])
        ]);
    }
};
m.mount(document.body, MeetingAdmin);
