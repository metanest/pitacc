require "pitacc"

class PitaCC::LL1;end
class <<PitaCC::LL1
    def build_table rule_list, nonterm_sym_list, term_sym_list
        #
        # calc nillable
        #
        nillable = {}
        rule_list.each {|rule|
            lhs = rule[:lhs]
            rhs = rule[:rhs]
            if rhs.empty? then
                nillable[lhs] = true
            end
        }
        loop {
            flag = true

            rule_list.each {|rule|
                lhs = rule[:lhs]
                rhs = rule[:rhs]
                unless nillable[lhs] then
                    if rhs.map {|sym| PitaCC::Util.terminal_or_not(sym) == :nonterminal and
                                      nillable[sym] }.all? then
                        flag = false
                        nillable[lhs] = true
                    end
                end
            }

            break if flag
        }

        #
        # calc First
        #
        first = {}
        term_sym_list.each {|sym|
            first[sym] = [sym]
        }
        nonterm_sym_list.each {|sym|
            first[sym] = []
        }
        loop {
            old_size = first.inspect.size

            rule_list.each {|rule|
                lhs = rule[:lhs]
                rhs = rule[:rhs]
                unless rhs.empty? then
                    first[lhs] |= first[rhs[0]]
                end
                idx = 0
                while rhs[idx] and nillable[rhs[idx]] and rhs[idx + 1] do
                    first[lhs] |= first[rhs[idx + 1]]
                    idx += 1
                end
            }

            break if first.inspect.size == old_size
        }

        #
        # calc follow
        #
        follow = {}
        nonterm_sym_list.each {|sym|
            follow[sym] = []
        }
        loop {
            old_size = follow.inspect.size

            rule_list.each {|rule|
                lhs = rule[:lhs]
                rhs = rule[:rhs]
                rhs.each_index {|idx|
                    sym = rhs[idx]
                    if PitaCC::Util.terminal_or_not(sym) == :terminal then
                        next
                    end
                    j = idx + 1
                    if rhs[j] then
                        while rhs[j] do
                            follow[sym] |= first[rhs[j]]
                            break unless nillable[rhs[j]]
                            j += 1
                        end
                        if j == rhs.size and nillable[rhs[j - 1]] then
                            follow[sym] |= follow[lhs]
                        end
                    else
                        follow[sym] |= follow[lhs]
                    end
                }
            }

            break if follow.inspect.size == old_size
        }

        #
        # director table
        #
        table = {}
        nonterm_sym_list.each {|sym|
            table[sym] = {}
            rules = []
            rule_list.each {|rule|
                rules << rule if rule[:lhs] == sym
            }
            rules.each {|rule|
                lhs = rule[:lhs]
                rhs = rule[:rhs]
                if rhs.empty? then
                    follow[lhs].each {|sym2|
                        table[sym][sym2] ||= []
                        table[sym][sym2] << rule
                    }
                else
                    idx = 0
                    fst = []
                    while rhs[idx] do
                        fst |= first[rhs[idx]]
                        break unless nillable[rhs[idx]]
                        idx += 1
                    end
                    if !rhs[idx] and nillable[rhs[idx - 1]] then
                        fst |= follow[lhs]
                    end
                    fst.each {|sym2|
                        table[sym][sym2] ||= []
                        table[sym][sym2] << rule
                    }
                end
            }
        }

        table.each_key {|nonterm|
            tmp = table[nonterm]
            tmp.each_key {|term|
                if tmp[term].size > 1 then
                    STDERR.puts "rule didn't unique for symbol \"#{term.inspect}\""
                    STDERR.puts "rules:"
                    tmp[term].each {|rule|
                        STDERR.puts PitaCC::Util.rule_to_s rule
                    }
                    raise
                end
            }
        }

        table.each_key {|nonterm|
            tbl = table[nonterm]
            tbl.each_key {|term|
                if tbl[term].size > 1 then
                    STDERR.puts "rule didn't unique for symbol \"#{term.inspect}\""
                    STDERR.puts "rules:"
                    tmp[term].each {|rule|
                        STDERR.puts PitaCC::Util.rule_to_s rule
                    }
                    raise
                end
                tmp = tbl[term]
                tbl[term] = tmp[0]
            }
        }

        return table
    end
end

class PitaCC::LL1
    def initialize
    end

    def parse parser, rule_list, table, lex
        stack = [[rule_list[0], 0, []]]

        loop {
            rule, ptr, buf = stack.pop
            sym = rule[:rhs][ptr]

            unless sym then
                handler = rule[:handler]
                val = if handler then
                          parser.instance_exec *buf, &handler
                      else
                          case buf.size
                          when 0 then
                              nil
                          when 1 then
                              buf[0]
                          else
                              buf
                          end
                      end
                rule, ptr, buf = stack.pop
                buf << val
                stack.push [rule, ptr + 1, buf]
                next
            end

            if sym == "$" then
                tokensym = lex.peek.sym
                if tokensym == "$" then
                    return buf[0]
                else
                    raise "unexpected token \"#{tokensym.inspect}\", expected is EOF"
                end
            end

            case PitaCC::Util.terminal_or_not sym
            when :terminal
                token = lex.peek
                if token.sym == sym then
                    token = lex.get
                    buf << if token.val then token.val else token.sym end
                else
                    raise "unexpected token \"#{token.sym.inspect}\", expected is \"#{sym.inspect}\""
                end
                stack.push [rule, ptr + 1, buf]
            when :nonterminal
                stack.push [rule, ptr, buf]  # save current state
                tbl = table[sym]
                tokensym = lex.peek.sym
                if rule2 = tbl[tokensym] then
                    stack.push [rule2, 0, []]
                else
                    STDERR.puts "unexpected token \"#{tokensym.inspect}\""
                    STDERR.print "expected is: "
                    STDERR.puts(tbl.keys.map {|x| "\"#{x.inspect}\"" }.join(" "))
                    raise
                end
            end
        }
    end
end
