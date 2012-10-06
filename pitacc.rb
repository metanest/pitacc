module PitaCC;end

module PitaCC::Util;end
class <<PitaCC::Util
    attr_accessor :nonterm

    def terminal_or_not sym
        case @nonterm
        when :up
            if /[A-Z]/.match sym.to_s[0, 1] then
                return :nonterminal
            else
                return :terminal
            end
        when :lo
            if /[a-z]/.match sym.to_s[0, 1] then
                return :terminal
            else
                return :nonterminal
            end
        end

        raise
    end

    def collect_sym rule_list
        term_sym_list = {}
        nonterm_sym_list = {}
        rule_list.each {|rule|
            lhs = rule[:lhs]
            if terminal_or_not(lhs) == :terminal then
                STDERR.puts "rule error in"
                STDERR.puts PitaCC::Util.rule_inspect rule
                raise "error: lhs must be nonterminal"
            end
            nonterm_sym_list[lhs] = true
            rule[:rhs].each {|sym|
                if terminal_or_not(sym) == :nonterminal then
                    nonterm_sym_list[sym] = true
                else
                    term_sym_list[sym] = true
                end
            }
        }
        return term_sym_list.keys, nonterm_sym_list.keys
    end

    def rule_to_s rule
        buf = "#{rule[:lhs]} -> "
        buf << rule[:rhs].map {|x| x.to_s }.join(" ")
        return buf
    end

    def rule_inspect rule
        return "rule #{rule[:lhs].inspect},  #{rule[:rhs].map {|x| x.inspect  }.join ", "}"
    end
end

class PitaCC::Parser;end
class <<PitaCC::Parser
    def set_engine name
        case name
        when :LL1
            @engine = PitaCC::LL1
        else
            raise
        end
    end

    def get_engine
        return @engine
    end

    def get_table
        return @table
    end

    def get_rule_list
        return @rule_list
    end

    PitaCC::Util.nonterm = nil

    def uppercase_is_nonterminal
        raise if PitaCC::Util.nonterm
        PitaCC::Util.nonterm = :up
    end

    def lowercase_is_terminal
        raise if PitaCC::Util.nonterm
        PitaCC::Util.nonterm = :lo
    end

    def rules &descriptions
        start = nil
        rule_list = []

        rules_collecter = BasicObject.new
        (class <<rules_collecter;self end).class_eval {
            define_method(:rule){|lhs, *rhs, &handler|
                start ||= lhs
                rule_list << { :lhs => lhs, :rhs => rhs, :handler => handler }
            }
        }
        rules_collecter.instance_eval &descriptions

        rule_list.each {|rule|
            unless rule[:lhs].is_a? Symbol and rule[:rhs].map {|x| x.is_a? Symbol }.all? then
                STDERR.puts "rule error in"
                STDERR.puts PitaCC::Util.rule_inspect rule
                raise "error: argument must be a Symbol"
            end
        }

        rule_list.unshift({ :lhs => "START", :rhs => [start, "$"], :handler => nil })
#=begin
        puts "**** Rules ****"
        rule_list.each_index {|i|
            rule = rule_list[i]
            buf = "#{i} "
            buf << PitaCC::Util.rule_to_s(rule)
            puts buf
        }
#=end
        term_sym_list, nonterm_sym_list = PitaCC::Util.collect_sym rule_list

        nonterm_sym_list.each {|sym|
            unless rule_list.map {|rule| rule[:lhs] }.index(sym) then
                raise "error: there is no rule(s) for nonterm #{sym}"
            end
        }

        @rule_list = rule_list
        @table = @engine.build_table rule_list, nonterm_sym_list, term_sym_list
    end
end

class PitaCC::Parser
    def parse lex
        engine = self.class.get_engine.new
        rule_list = self.class.get_rule_list
        table = self.class.get_table
        engine.parse self, rule_list, table, lex
    end
end
